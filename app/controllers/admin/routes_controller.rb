module Admin
  class RoutesController < BaseController
    before_action :require_planner_role

    def show
      @date = Date.current
      @couriers = User.where(role: "courier").order(:id).to_a
      @stops_by_courier = build_stops_by_courier(@couriers)
      @lane_summaries = build_lane_summaries(@couriers)
    end

    def optimize
      selected = Array(params[:courier_ids]).map(&:to_i).reject(&:zero?)
      courier_ids = selected.presence || User.where(role: "courier").pluck(:id)
      result = Routes::DailyRouteOptimizer.run(courier_ids: courier_ids)

      cache_lane_summary(result) if result[:ordered].positive?

      notice =
        if result[:ordered].positive?
          "Маршрутът е оптимизиран — #{result[:ordered]} спирки разпределени между #{result[:lanes].size} куриера."
        else
          "Няма спирки за оптимизация."
        end
      redirect_to admin_route_path, notice: notice
    end

    def calculate
      lane_id = params[:lane].to_i
      stops = lane_stops_for(lane_id)
      if stops.empty?
        redirect_to admin_route_path, alert: "Няма спирки за изчисление." and return
      end

      result = Google::Routes.calculate(stops: stops)
      if result.nil?
        redirect_to admin_route_path,
                    alert: "Неуспешно извличане от Google Maps. Проверете API ключа."
        return
      end

      cache_lane(lane_id, stops.map(&:id), result.distance_km, result.total_minutes)
      redirect_to admin_route_path,
                  notice: "Изчислено: %.1f км, %s." % [result.distance_km, view_context.format_minutes_bg(result.total_minutes)]
    end

    def reorder
      lane_id = params[:lane].presence&.to_i
      ids = Array(params[:ordered_ids]).map(&:to_i)

      Request.transaction do
        ids.each_with_index do |id, index|
          stop = Request.find_by(id: id)
          next unless stop

          updates = { route_position: index + 1 }
          if params.key?(:lane)
            if stop.status.in?(%w[pickup_confirmed picked_up])
              updates[:pickup_courier_id] = lane_id
            elsif stop.status.in?(%w[delivery_confirmed delivered])
              updates[:delivery_courier_id] = lane_id
            end
          end
          stop.update_columns(updates)
        end
      end

      Rails.cache.delete_matched("route/optimized/*") if Rails.cache.respond_to?(:delete_matched)
      head :no_content
    end

    private

    def require_planner_role
      unless current_admin&.admin? || current_admin&.coordinator?
        redirect_to admin_requests_path, alert: "Достъп само за администратори и координатори."
      end
    end

    def open_stops
      tz = Request.factory_tz_sql
      Request.where(
        "(status = 'pickup_confirmed' AND (pick_up_at AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date = :d) " \
        "OR (status = 'delivery_confirmed' AND (delivery_at AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date = :d)",
        d: Date.current,
      ).order(Arel.sql("route_position NULLS LAST"))
       .order(:pick_up_at, :delivery_at, :created_at)
    end

    def lane_stops_for(courier_id)
      open_stops.select { |s| effective_courier_id(s) == courier_id }
    end

    def effective_courier_id(stop)
      stop.status.in?(%w[pickup_confirmed picked_up]) ? stop.pickup_courier_id : stop.delivery_courier_id
    end

    def build_stops_by_courier(couriers)
      stops = open_stops.to_a
      groups = couriers.each_with_object({}) { |c, h| h[c.id] = [] }
      groups[nil] = []
      stops.each { |s| (groups[effective_courier_id(s)] ||= []) << s }
      groups
    end

    def build_lane_summaries(couriers)
      summaries = {}
      couriers.each do |c|
        cached = Rails.cache.read(lane_cache_key(Date.current, c.id))
        current_ids = lane_stops_for(c.id).map(&:id)
        if cached && cached[:ordered_ids] == current_ids && cached[:distance_km]
          summaries[c.id] = cached
        else
          summaries[c.id] = { distance_km: nil, total_minutes: nil }
        end
      end
      summaries
    end

    def cache_lane(courier_id, ordered_ids, distance_km, total_minutes)
      Rails.cache.write(
        lane_cache_key(Date.current, courier_id),
        { ordered_ids: ordered_ids, distance_km: distance_km, total_minutes: total_minutes },
        expires_in: 1.day,
      )
    end

    def cache_lane_summary(result)
      result[:lanes].each do |courier_id, ordered_ids|
        cache_lane(courier_id, ordered_ids, nil, nil)
      end
    end

    def lane_cache_key(date, courier_id)
      "route/optimized/#{date.iso8601}/courier/#{courier_id}"
    end
  end
end
