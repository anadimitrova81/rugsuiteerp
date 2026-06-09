module Admin
  class SmsLogController < BaseController
    before_action :require_admin_or_coordinator

    PER_PAGE = 25

    def index
      @query = params[:q].to_s.strip
      @status_filter = params[:status].to_s.presence_in(%w[failed sent])
      @from_date = parse_date(params[:from])
      @to_date = parse_date(params[:to])

      scope = Notification.where(kind: "price_quote").includes(:request)
      scope = scope.where(status: @status_filter) if @status_filter
      if @query.present?
        like = "%#{@query}%"
        scope = scope.joins(:request).where(
          "notifications.recipient ILIKE :q OR requests.customer_id ILIKE :q OR requests.phone ILIKE :q",
          q: like,
        )
      end
      scope = scope.where("sent_at >= ?", @from_date.in_time_zone.beginning_of_day) if @from_date
      scope = scope.where("sent_at <= ?", @to_date.in_time_zone.end_of_day) if @to_date

      @total_count = scope.count
      @page = [params[:page].to_i, 1].max
      @notifications = scope.sms_log.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      @has_more = @total_count > @page * PER_PAGE
      @failed_count = Notification.where(kind: "price_quote", status: "failed").count

      # Only "load more" (?page=N as a Turbo Stream) appends; everything else
      # renders the full list.
      if params[:page].present? && request.format.turbo_stream?
        render :index
      else
        render :index, formats: [:html]
      end
    end

    private

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue ArgumentError, Date::Error
      nil
    end

    def require_admin_or_coordinator
      unless current_admin&.admin? || current_admin&.coordinator?
        redirect_to admin_requests_path, alert: t("admin.sms_log.admin_only")
      end
    end
  end
end
