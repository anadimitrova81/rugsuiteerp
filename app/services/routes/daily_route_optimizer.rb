module Routes
  # Computes a near-optimal visit order for a courier's remaining stops today
  # using a nearest-neighbour heuristic on great-circle distance. Persists the
  # result on `requests.route_position` so the courier UI can sort by it.
  #
  # Trade-offs vs. a real routing API:
  #   * Free, no quota, no key.
  #   * Doesn't account for traffic, one-way streets, road closures.
  #   * Distances use Haversine — straight-line, not driving distance.
  # For ~10 stops in one town this gives a sensible order in practice;
  # couriers can always re-shuffle by following Google Maps' actual directions.
  class DailyRouteOptimizer
    # The depot (start and end of every route) and the per-city fallback
    # coordinates come from the company's settings — see FactoryRoutePlanning.

    EARTH_RADIUS_KM = 6371.0

    def self.run(date: Date.current, courier_ids: nil, balance_time: true)
      new(date: date, courier_ids: courier_ids, balance_time: balance_time).run
    end

    # Re-orders an existing set of stops for one courier without changing who
    # carries them: Google's optimizer when available, nearest-neighbour
    # otherwise. Persists route_position and returns the ordered ids plus
    # distance/time when Google supplied them.
    def self.order_lane(stops)
      google = Google::Routes.optimize(stops: stops)
      ordered = google&.ordered_stops || nearest_neighbour_order(stops, origin: origin_for(stops))

      Request.transaction do
        ordered.each_with_index do |request, index|
          request.update_columns(route_position: index + 1)
        end
      end

      {
        ordered_ids: ordered.map(&:id),
        distance_km: google&.distance_km,
        total_minutes: google&.total_minutes,
      }
    end

    def self.nearest_neighbour_order(stops, origin:)
      remaining = stops.dup
      ordered = []
      current = origin

      while remaining.any?
        next_stop = remaining.min_by { |stop| haversine(current, coordinates_for(stop, origin: origin)) }
        ordered << next_stop
        current = coordinates_for(next_stop, origin: origin)
        remaining.delete(next_stop)
      end

      ordered
    end

    # Where routes start and end: the company's depot (or the middle of its
    # service area). With neither set yet, the middle of the pinned stops —
    # and as a last resort a fixed point, which still yields a consistent
    # order, just without a meaningful start.
    def self.origin_for(stops, factory: Request.current_factory)
      factory.route_origin || begin
        pins = stops.filter_map { |s| pinned_coordinates(s) }
        pins.any? ? [ pins.sum { |c| c[0] } / pins.size, pins.sum { |c| c[1] } / pins.size ] : [ 0.0, 0.0 ]
      end
    end

    def self.pinned_coordinates(request)
      request.verified_address.split(",").map(&:to_f) if request.verified_address.to_s.match?(ApplicationHelper::COORDINATES_REGEX)
    end

    # Coordinates used for routing this request: the coordinator's pin
    # (`verified_address` as lat,lng), else its city's coordinate from the
    # company settings, else the route origin.
    def self.coordinates_for(request, origin:, factory: Request.current_factory)
      pinned_coordinates(request) || factory.coordinates_for_city(request.city) || origin
    end

    # Used by `nearest_neighbour_order` (the fallback ordering heuristic when
    # Google Directions isn't available). Not exposed for distance/time
    # display — those numbers come exclusively from Google.
    def self.haversine(a, b)
      lat1, lon1 = a
      lat2, lon2 = b
      d_lat = (lat2 - lat1) * Math::PI / 180
      d_lon = (lon2 - lon1) * Math::PI / 180
      sin_lat = Math.sin(d_lat / 2)
      sin_lon = Math.sin(d_lon / 2)
      x = sin_lat**2 +
          Math.cos(lat1 * Math::PI / 180) *
          Math.cos(lat2 * Math::PI / 180) *
          sin_lon**2
      EARTH_RADIUS_KM * 2 * Math.asin(Math.sqrt(x))
    end

    # `balance_time: false` skips the time-balancing pass, leaving the plain
    # greedy split (the planner exposes this as a checkbox).
    def initialize(date:, courier_ids: nil, balance_time: true)
      @date = date
      @courier_ids = Array(courier_ids).compact
      @balance_time = balance_time
    end

    def run
      stops = open_stops_for(@date)
      return empty_result if stops.empty?

      @origin = self.class.origin_for(stops)

      courier_ids = @courier_ids.presence || default_courier_ids
      return single_lane_run(stops) if courier_ids.size <= 1

      lanes = distribute_across_couriers(stops, courier_ids)

      Request.transaction do
        lanes.each do |courier_id, lane_stops|
          ordered = nearest_neighbour_order(lane_stops)
          ordered.each_with_index do |request, index|
            request.update_columns(
              pickup_courier_id: (request.status.in?(%w[pickup_confirmed picked_up]) ? courier_id : request.pickup_courier_id),
            delivery_courier_id: (request.status.in?(%w[delivery_confirmed delivered]) ? courier_id : request.delivery_courier_id),
              route_position: index + 1,
            )
          end
        end
      end

      {
        ordered: stops.size,
        total: stops.size,
        ordered_ids: lanes.values.flatten.map(&:id),
        distance_km: nil,
        total_minutes: nil,
        lanes: lanes.transform_values { |s| s.map(&:id) },
      }
    end

    private

    def default_courier_ids
      User.couriers.order(:id).pluck(:id)
    end

    def empty_result
      { ordered: 0, total: 0, ordered_ids: [], distance_km: nil, total_minutes: nil, lanes: {} }
    end

    def single_lane_run(stops)
      courier_id = (@courier_ids.first || default_courier_ids.first)
      google_result = Google::Routes.optimize(stops: stops)
      ordered = google_result&.ordered_stops || nearest_neighbour_order(stops)

      Request.transaction do
        ordered.each_with_index do |request, index|
          request.update_columns(
            pickup_courier_id: (request.status.in?(%w[pickup_confirmed picked_up]) ? courier_id : request.pickup_courier_id),
            delivery_courier_id: (request.status.in?(%w[delivery_confirmed delivered]) ? courier_id : request.delivery_courier_id),
            route_position: index + 1,
          )
        end
      end

      {
        ordered: ordered.size,
        total: stops.size,
        ordered_ids: ordered.map(&:id),
        distance_km: google_result&.distance_km,
        total_minutes: google_result&.total_minutes,
        lanes: { courier_id => ordered.map(&:id) },
      }
    end

    # Greedy load balancing: each iteration the courier with the fewest stops
    # picks their nearest unassigned stop. Produces count-balanced lanes that
    # also respect rough geography.
    def distribute_across_couriers(stops, courier_ids)
      remaining = stops.dup
      lanes = courier_ids.index_with { [] }
      current_positions = courier_ids.index_with { @origin }

      while remaining.any?
        # Courier with fewest stops, ties broken by lower id for determinism.
        next_courier = courier_ids.min_by { |id| [lanes[id].size, id] }
        from = current_positions[next_courier]
        stop = remaining.min_by { |s| self.class.haversine(from, coordinates_for(s)) }
        lanes[next_courier] << stop
        current_positions[next_courier] = coordinates_for(stop)
        remaining.delete(stop)
      end

      @balance_time ? rebalance_lanes(lanes) : lanes
    end

    # Knobs for the time-balancing pass. The minutes are *estimates* built from
    # straight-line distance — good enough to compare lanes against each other,
    # never shown to couriers or coordinators (display numbers come from
    # Google). ~2 min/km ≈ 30 km/h door-to-door; 5 min per stop covers parking,
    # handover and carrying.
    ESTIMATED_MINUTES_PER_KM = 2.0
    STOP_SERVICE_MINUTES = 5
    BALANCE_TOLERANCE_MINUTES = 30
    MAX_REBALANCE_MOVES = 20

    # The greedy split balances stop *counts*, so a courier with a few far-away
    # villages can end up with a much longer day than one working the city.
    # While the gap between the longest and shortest lane (by estimated time)
    # exceeds the tolerance, the longest lane hands the stop nearest to the
    # shortest lane's centroid over to it. A lane is never emptied, and a move
    # must both shrink the gap AND shorten the longest lane — otherwise the
    # "balance" would come from making everyone's day longer, and the pass stops.
    def rebalance_lanes(lanes)
      return lanes if lanes.size < 2

      MAX_REBALANCE_MOVES.times do
        minutes = lanes.transform_values { |stops| estimated_minutes(stops) }
        donor_id, donor_minutes = minutes.max_by { |id, m| [m, -id] }
        receiver_id, receiver_minutes = minutes.min_by { |id, m| [m, id] }
        gap = donor_minutes - receiver_minutes
        break if gap <= BALANCE_TOLERANCE_MINUTES

        donor = lanes[donor_id]
        break if donor.size <= 1

        receiver_centre = centroid_of(lanes[receiver_id])
        stop = donor.min_by { |s| [self.class.haversine(coordinates_for(s), receiver_centre), s.id] }

        new_donor = donor - [stop]
        new_receiver = lanes[receiver_id] + [stop]
        new_minutes = minutes.merge(donor_id => estimated_minutes(new_donor), receiver_id => estimated_minutes(new_receiver))
        break unless new_minutes.values.max < donor_minutes && new_minutes.values.max - new_minutes.values.min < gap

        lanes[donor_id] = new_donor
        lanes[receiver_id] = new_receiver
      end

      lanes
    end

    # Rough minutes for one courier to run these stops: nearest-neighbour tour
    # length from/to the depot on great-circle distance, converted to driving
    # minutes, plus fixed service time per stop.
    def estimated_minutes(stops)
      return 0.0 if stops.empty?

      km = 0.0
      current = @origin
      nearest_neighbour_order(stops).each do |stop|
        coord = coordinates_for(stop)
        km += self.class.haversine(current, coord)
        current = coord
      end
      km += self.class.haversine(current, @origin)

      km * ESTIMATED_MINUTES_PER_KM + stops.size * STOP_SERVICE_MINUTES
    end

    def centroid_of(stops)
      return @origin if stops.empty?

      coords = stops.map { |s| coordinates_for(s) }
      [coords.sum { |c| c[0] } / coords.size, coords.sum { |c| c[1] } / coords.size]
    end

    # All courier-relevant pickups + deliveries scheduled for `date` that
    # haven't been completed yet.
    def open_stops_for(date)
      tz = Request.factory_tz_sql
      Request.where(
        "(status = 'pickup_confirmed' AND (pick_up_at AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date = :d) " \
        "OR (status = 'delivery_confirmed' AND (delivery_at AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date = :d)",
        d: date,
      ).to_a
    end

    def nearest_neighbour_order(stops)
      self.class.nearest_neighbour_order(stops, origin: @origin)
    end

    def coordinates_for(stop)
      self.class.coordinates_for(stop, origin: @origin)
    end
  end
end
