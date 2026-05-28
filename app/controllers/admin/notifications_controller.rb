module Admin
  class NotificationsController < BaseController
    before_action :require_admin_or_coordinator

    def price_quotes
      pending = Request.awaiting_price_notification.where.not(amount: nil)

      if pending.none?
        redirect_back fallback_location: admin_requests_path,
                      alert: "Няма поръчки за изпращане на ценови оферти."
        return
      end

      sent = 0
      failed = 0
      pending.find_each do |request|
        body = Sms::PriceQuoteMessage.build(request)
        begin
          Sms::Sender.deliver(to: request.phone, body: body)
          request.notifications.create!(
            kind: "price_quote", channel: "sms", recipient: request.phone,
            body: body, status: "sent", sent_at: Time.current,
          )
          sent += 1
        rescue Sms::Sender::DeliveryError => e
          Rails.logger.error("[price_quotes] failed ##{request.customer_id}: #{e.message}")
          request.notifications.create!(
            kind: "price_quote", channel: "sms", recipient: request.phone,
            body: body, status: "failed", error_message: e.message, sent_at: Time.current,
          )
          failed += 1
        end
      end

      flash_for(sent: sent, failed: failed)
      redirect_back fallback_location: admin_requests_path
    end

    private

    def require_admin_or_coordinator
      unless current_admin&.admin? || current_admin&.coordinator?
        redirect_to admin_requests_path, alert: "Достъп само за администратори и координатори."
      end
    end

    def flash_for(sent:, failed:)
      if sent.positive? && failed.zero?
        flash[:notice] = "Изпратени SMS оферти за #{sent} #{sent == 1 ? "поръчка" : "поръчки"}."
      elsif sent.positive?
        flash[:alert] = "Изпратени: #{sent}. Неуспешни: #{failed}. Виж логовете."
      else
        flash[:alert] = "Изпращането на SMS оферти се провали за #{failed} #{failed == 1 ? "поръчка" : "поръчки"}. Виж логовете."
      end
    end
  end
end
