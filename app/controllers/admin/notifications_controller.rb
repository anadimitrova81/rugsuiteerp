module Admin
  class NotificationsController < BaseController
    before_action :require_admin_or_coordinator

    def price_quotes
      pending = Request.awaiting_price_notification.where.not(amount: nil)

      if pending.none?
        redirect_back fallback_location: admin_requests_path,
                      alert: t("admin.notifications.no_pending")
        return
      end

      sent = 0
      failed = 0
      pending.find_each do |request|
        if Notification.deliver_price_quote(request).status == "sent"
          sent += 1
        else
          failed += 1
        end
      end

      flash_for(sent: sent, failed: failed)
      redirect_back fallback_location: admin_requests_path
    end

    private

    def require_admin_or_coordinator
      unless current_admin&.admin? || current_admin&.coordinator?
        redirect_to admin_requests_path, alert: t("admin.sms_log.admin_only")
      end
    end

    def flash_for(sent:, failed:)
      if sent.positive? && failed.zero?
        flash[:notice] = t("admin.notifications.sent", count: sent)
      elsif sent.positive?
        flash[:alert] = t("admin.notifications.partial_failure", sent: sent, failed: failed)
      else
        flash[:alert] = t("admin.notifications.all_failed", count: failed)
      end
    end
  end
end
