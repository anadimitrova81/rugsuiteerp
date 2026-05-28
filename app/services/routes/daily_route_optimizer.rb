module Routes
  # Computes a near-optimal visit order for a courier's remaining stops today
  # using a nearest-neighbour heuristic on great-circle distance. Persists the
  # result on `requests.route_position` so the courier UI can sort by it.
  #
  # Trade-offs vs. a real routing API:
  #   * Free, no quota, no key.
  #   * Doesn't account for traffic, one-way streets, road closures.
  #   * Distances use Haversine — straight-line, not driving distance.
  # For ~10 stops in the Plovdiv area this gives a sensible order in practice;
  # couriers can always re-shuffle by following Google Maps' actual directions.
  class DailyRouteOptimizer
    # The factory: с. Труд, ул. Карловско шосе 54A. Couriers start and
    # end every route here, so this drives both the haversine fallback
    # ordering and the origin/destination of the Google Directions call.
    DEPOT = [42.2189958, 24.7289106].freeze
    DEPOT_ADDRESS = "с. Труд, ул. Карловско шосе 54A".freeze

    # Approximate centroids for served settlements. Used as a fallback when a
    # request has no coordinate-form `verified_address`.
    CITY_CENTROIDS = {
      "Пловдив" => [42.1454, 24.7497],
      "Асеновград" => [42.0117, 24.8740],
      "Брани поле" => [42.0683, 24.6489],
      "Брестник" => [42.0950, 24.7783],
      "Брестовица" => [42.0656, 24.6094],
      "Войводиново" => [42.2042, 24.7700],
      "Злати трап" => [42.1408, 24.5694],
      "Йоаким Груево" => [42.0953, 24.5825],
      "Крумово" => [42.0792, 24.7878],
      "Марково" => [42.0903, 24.6697],
      "Перущица" => [42.0508, 24.5547],
      "Първенец" => [42.0794, 24.6569],
      "Строево" => [42.1875, 24.6253],
      "Труд" => [42.2222, 24.7256],
      "Храбрино" => [42.0233, 24.6303],
      "Цалапица" => [42.1872, 24.5467],
    }.freeze

    EARTH_RADIUS_KM = 6371.0

    def self.run(date: Date.current, courier_ids: nil)
      new(date: date, courier_ids: courier_ids).run
    end

    # Coordinates used for routing this request. Falls back to the city centroid
    # when no `verified_address` (lat,lng) has been pasted by the coordinator.
    def self.coordinates_for(request)
      if request.verified_address.to_s.match?(ApplicationHelper::COORDINATES_REGEX)
        request.verified_address.split(",").map(&:to_f)
      else
        CITY_CENTROIDS[request.city] || DEPOT
      end
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

    def initialize(date:, courier_ids: nil)
      @date = date
      @courier_ids = Array(courier_ids).compact
    end

    def run
      stops = open_stops_for(@date)
      return empty_result if stops.empty?

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
      User.where(role: "courier").order(:id).pluck(:id)
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
      current_positions = courier_ids.index_with { DEPOT }

      while remaining.any?
        # Courier with fewest stops, ties broken by lower id for determinism.
        next_courier = courier_ids.min_by { |id| [lanes[id].size, id] }
        from = current_positions[next_courier]
        stop = remaining.min_by { |s| self.class.haversine(from, self.class.coordinates_for(s)) }
        lanes[next_courier] << stop
        current_positions[next_courier] = self.class.coordinates_for(stop)
        remaining.delete(stop)
      end

      lanes
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
      remaining = stops.dup
      ordered = []
      current = DEPOT

      while remaining.any?
        next_stop = remaining.min_by { |stop| self.class.haversine(current, self.class.coordinates_for(stop)) }
        ordered << next_stop
        current = self.class.coordinates_for(next_stop)
        remaining.delete(next_stop)
      end

      ordered
    end
  end
end
