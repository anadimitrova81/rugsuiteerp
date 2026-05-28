module Admin
  class ReportsController < BaseController
    before_action :require_admin_role

    PERIODS = {
      "today" => { label: "Днес", since: -> { Time.current.beginning_of_day } },
      "7" => { label: "Последните 7 дни", since: -> { 7.days.ago.beginning_of_day } },
      "30" => { label: "Последните 30 дни", since: -> { 30.days.ago.beginning_of_day } },
      "90" => { label: "Последните 90 дни", since: -> { 90.days.ago.beginning_of_day } },
    }.freeze

    def index
      @periods = PERIODS
      @period_key = PERIODS.key?(params[:period]) ? params[:period] : "30"
      @period = PERIODS[@period_key]
      since_at = @period[:since].call

      created_in_period = Request.where(created_at: since_at..)
      delivered_in_period = Request.where(status: "delivered", updated_at: since_at..)
      cancelled_in_period = Request.where(status: "cancelled", updated_at: since_at..)

      @kpis = {
        total: created_in_period.count,
        delivered: delivered_in_period.count,
        revenue: delivered_in_period.sum(:amount).to_f,
        cancelled: cancelled_in_period.count,
      }

      @status_counts = created_in_period.group(:status).count
      @top_cities = created_in_period.group(:city).order(Arel.sql("COUNT(*) DESC")).limit(6).count

      @averages = {
        items: delivered_in_period.average(:number_of_items)&.to_f,
        weight: delivered_in_period.average(:weight)&.to_f,
        amount: delivered_in_period.average(:amount)&.to_f,
      }

      @daily_volume = build_daily_volume(since_at)

      visits_in_period = PageVisit.where(created_at: since_at..)
      @page_views = visits_in_period.group(:route_key).order(Arel.sql("COUNT(*) DESC")).count
      @daily_visits = build_daily_visits(since_at)
      @funnel = {
        home: @page_views["pages#home"].to_i,
        form: @page_views["requests#new"].to_i,
        submitted: @kpis[:total],
      }
    end

    private

    def require_admin_role
      unless current_admin&.admin?
        redirect_to admin_requests_path, alert: "Достъп само за администратори."
      end
    end

    def build_daily_volume(since_at)
      timestamps = Request.where(created_at: since_at..).pluck(:created_at)
      counts = timestamps.group_by { |t| t.in_time_zone.to_date }.transform_values(&:size)
      start_date = since_at.in_time_zone.to_date
      (start_date..Date.current).map { |d| [d, counts[d].to_i] }
    end

    def build_daily_visits(since_at)
      timestamps = PageVisit.where(created_at: since_at..).pluck(:created_at)
      counts = timestamps.group_by { |t| t.in_time_zone.to_date }.transform_values(&:size)
      start_date = since_at.in_time_zone.to_date
      (start_date..Date.current).map { |d| [d, counts[d].to_i] }
    end
  end
end
