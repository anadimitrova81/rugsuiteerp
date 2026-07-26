module Admin
  class RoutesController < BaseController
    before_action :require_planner_role
    before_action :enforce_route_operation_limit, only: %i[optimize calculate]

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

      if result[:ordered].positive?
        cache_lane_summary(result)
        current_factory.record_route_operation!
      end

      notice =
        if result[:ordered].positive?
          t("admin.routes.optimize_success", count: result[:ordered], couriers: result[:lanes].size)
        else
          t("admin.routes.optimize_none")
        end
      redirect_to admin_route_path, notice: notice
    end

    def calculate
      lane_id = params[:lane].to_i
      stops = lane_stops_for(lane_id)
      if stops.empty?
        redirect_to admin_route_path, alert: t("admin.routes.calculate_empty") and return
      end

      result = Google::Routes.calculate(stops: stops)
      if result.nil?
        redirect_to admin_route_path,
                    alert: t("admin.routes.calculate_failed")
        return
      end

      cache_lane(lane_id, stops.map(&:id), result.distance_km, result.total_minutes)
      current_factory.record_route_operation!
      redirect_to admin_route_path,
                  notice: t("admin.routes.calculate_success",
                            distance: format("%.1f", result.distance_km),
                            duration: view_context.format_minutes_bg(result.total_minutes))
    end

    # Swap two couriers' whole routes: everything assigned to `from` goes to
    # `to` and vice versa, keeping each route's sequence (route_position)
    # intact — only the driver changes.
    def swap
      a = params[:from].to_i
      b = params[:to].to_i
      if a.zero? || b.zero? || a == b
        redirect_to admin_route_path, alert: t("admin.routes.swap_invalid") and return
      end

      Request.transaction do
        open_stops.each do |stop|
          effective = effective_courier_id(stop)
          next unless [ a, b ].include?(effective)

          target = effective == a ? b : a
          field = stop.status.in?(%w[pickup_confirmed picked_up]) ? :pickup_courier_id : :delivery_courier_id
          stop.update_columns(field => target)
        end
      end

      swap_lane_caches(a, b)
      redirect_to admin_route_path, notice: t("admin.routes.swap_success")
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
        redirect_to admin_requests_path, alert: t("admin.sms_log.admin_only")
      end
    end

    # Route optimise + calculate share a per-day, per-plan quota (both hit the
    # Google Routes API). Block once the day's allowance is used up.
    def enforce_route_operation_limit
      return unless current_factory.route_operation_limit_reached?

      redirect_to admin_route_path,
                  alert: t("admin.limits.route_operation.reached", limit: current_factory.route_operation_limit)
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

    # After a swap the routes themselves are unchanged, so move each cached
    # distance/time summary to the courier now driving that route rather than
    # forcing a recalculation.
    def swap_lane_caches(a, b)
      key_a = lane_cache_key(Date.current, a)
      key_b = lane_cache_key(Date.current, b)
      cached_a = Rails.cache.read(key_a)
      cached_b = Rails.cache.read(key_b)

      cached_b ? Rails.cache.write(key_a, cached_b, expires_in: 1.day) : Rails.cache.delete(key_a)
      cached_a ? Rails.cache.write(key_b, cached_a, expires_in: 1.day) : Rails.cache.delete(key_b)
    end
  end
end
