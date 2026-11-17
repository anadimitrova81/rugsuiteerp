class Notification < ApplicationRecord
  acts_as_tenant :factory

  KINDS = %w[price_quote].freeze
  CHANNELS = %w[sms].freeze
  STATUSES = %w[sent failed].freeze

  belongs_to :request

  validates :kind, inclusion: { in: KINDS }
  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }

  scope :sms_log, -> { order(sent_at: :desc) }

  # Builds the price quote from the order's current weight, amount and phone,
  # sends it and logs the attempt either way. Returns the logged notification.
  def self.deliver_price_quote(request)
    body = Sms::PriceQuoteMessage.build(request)
    attrs = { kind: "price_quote", channel: "sms", recipient: request.phone, body: body, sent_at: Time.current }
    Sms::Sender.deliver(to: request.phone, body: body)
    request.notifications.create!(attrs.merge(status: "sent"))
  rescue Sms::Sender::DeliveryError => e
    Rails.logger.error("[price_quotes] failed ##{request.customer_id}: #{e.message}")
    request.notifications.create!(attrs.merge(status: "failed", error_message: e.message))
  end
end
