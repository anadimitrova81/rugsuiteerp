module Admin
  class SmsLogController < BaseController
    before_action :require_admin_or_coordinator

    def index
      @query = params[:q].to_s.strip
      @status_filter = params[:status].to_s.presence_in(%w[failed sent])

      scope = Notification.where(kind: "price_quote").includes(:request)
      scope = scope.where(status: @status_filter) if @status_filter
      if @query.present?
        like = "%#{@query}%"
        scope = scope.joins(:request).where(
          "notifications.recipient ILIKE :q OR requests.customer_id ILIKE :q OR requests.phone ILIKE :q",
          q: like,
        )
      end
      @notifications = scope.sms_log.limit(100)
      @failed_count = Notification.where(kind: "price_quote", status: "failed").count
    end

    private

    def require_admin_or_coordinator
      unless current_admin&.admin? || current_admin&.coordinator?
        redirect_to admin_requests_path, alert: "Достъп само за администратори и координатори."
      end
    end
  end
end
