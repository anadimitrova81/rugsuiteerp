module Admin
  class ReportsController < BaseController
    before_action :require_admin_role

    # Period labels live in I18n under admin.reports.periods.<key> so the view
    # renders them in the factory's language.
    PERIODS = {
      "today" => { since: -> { Time.current.beginning_of_day } },
      "7"     => { since: -> { 7.days.ago.beginning_of_day } },
      "30"    => { since: -> { 30.days.ago.beginning_of_day } },
      "90"    => { since: -> { 90.days.ago.beginning_of_day } },
    }.freeze

    def index
      @periods = PERIODS
      @from_date = parse_date(params[:from])
      @to_date = parse_date(params[:to])
      since_at, until_at, start_date, end_date = resolve_range

      range = since_at..until_at
      created_in_period = Request.where(created_at: range)
      # Delivered orders count by their delivery date — the day the money is
      # earned — so editing an old order later doesn't move it into this period.
      delivered_in_period = Request.where(status: "delivered", delivery_at: range)
      cancelled_in_period = Request.where(status: "cancelled", updated_at: range)

      @kpis = {
        total: created_in_period.count,
        delivered: delivered_in_period.count,
        revenue: delivered_in_period.sum(:amount).to_f,
        cancelled: cancelled_in_period.count,
        weight: Request.where(delivery_at: range).sum(:weight).to_f,
      }

      @status_counts = created_in_period.group(:status).count
      @status_weights = created_in_period.group(:status).sum(:weight)
      @top_cities = created_in_period.group(:city).order(Arel.sql("COUNT(*) DESC")).limit(6).count

      @averages = {
        items: delivered_in_period.average(:number_of_items)&.to_f,
        weight: delivered_in_period.average(:weight)&.to_f,
        amount: delivered_in_period.average(:amount)&.to_f,
      }

      @courier_collections = build_courier_collections(range)

      @daily_volume = build_daily(Request, range, start_date, end_date)

      visits_in_period = PageVisit.where(created_at: range)
      @page_views = visits_in_period.group(:route_key).order(Arel.sql("COUNT(*) DESC")).count
      @daily_visits = build_daily(PageVisit, range, start_date, end_date)
      @funnel = {
        home: @page_views["pages#home"].to_i,
        form: @page_views["requests#new"].to_i,
        submitted: @kpis[:total],
      }
    end

    private

    def require_admin_role
      unless current_admin&.admin?
        redirect_to admin_requests_path, alert: t("admin.reports.admin_only")
      end
    end

    # Resolves the reporting window. A custom from/to range (either bound)
    # overrides the preset period; otherwise the chosen/default preset applies.
    # Returns [since_at(Time), until_at(Time|nil), start_date(Date), end_date(Date)].
    def resolve_range
      if @from_date || @to_date
        start_date = @from_date || @to_date
        end_date = @to_date || Date.current
        start_date, end_date = end_date, start_date if start_date > end_date

        @period_key = nil
        @period_label = "#{start_date.strftime('%d.%m.%Y')} – #{end_date.strftime('%d.%m.%Y')}"
        [ start_date.in_time_zone.beginning_of_day, end_date.in_time_zone.end_of_day, start_date, end_date ]
      else
        @period_key = PERIODS.key?(params[:period]) ? params[:period] : "30"
        @period_label = t("admin.reports.periods.#{@period_key}")
        since_at = PERIODS[@period_key][:since].call
        [ since_at, nil, since_at.in_time_zone.to_date, Date.current ]
      end
    end

    # The period's deliveries per courier, by delivery date: what the courier
    # collected in hand (cash / card — the same rules as their own "collected
    # today" box) and what is billed by invoice instead, so the table adds up
    # to the revenue KPI. Returns rows of
    # { courier:, count:, cash:, card:, invoiced:, total: }, biggest total
    # first; orders with no delivery courier recorded end up in a row with
    # courier: nil.
    def build_courier_collections(range)
      delivered = Request.where(status: "delivered", delivery_at: range)
      counts = delivered.group(:delivery_courier_id).count
      return [] if counts.empty?

      totals = delivered.group(:delivery_courier_id).sum(:amount)
      collected = delivered.merge(Request.collected_by_courier)
      cash = collected.where(paid_by_card: false).group(:delivery_courier_id).sum(:amount)
      cards = collected.where(paid_by_card: true).group(:delivery_courier_id).sum(:amount)
      couriers = User.where(id: counts.keys.compact).index_by(&:id)

      counts.keys.map do |courier_id|
        total = totals[courier_id].to_f
        row = { courier: couriers[courier_id], count: counts[courier_id],
                cash: cash[courier_id].to_f, card: cards[courier_id].to_f, total: total, }
        row.merge(invoiced: (total - row[:cash] - row[:card]).round(2))
      end.sort_by { |row| [-row[:total], row[:courier]&.email.to_s] }
    end

    def build_daily(relation, range, start_date, end_date)
      timestamps = relation.where(created_at: range).pluck(:created_at)
      counts = timestamps.group_by { |t| t.in_time_zone.to_date }.transform_values(&:size)
      (start_date..end_date).map { |d| [ d, counts[d].to_i ] }
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue ArgumentError, Date::Error
      nil
    end
  end
end
