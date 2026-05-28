module Sms
  # Public entry point. Routes to the configured backend.
  module Sender
    DeliveryError = Class.new(StandardError)

    def self.deliver(to:, body:)
      # smsapi.bg only accepts E.164; convert 088... → +359888... here so
      # callers can pass whatever shape the database has.
      backend.deliver(to: PhoneNumber.normalize(to), body: body)
    end

    def self.backend
      @backend ||= build_backend
    end

    def self.backend=(value)
      @backend = value
    end

    def self.reset_backend!
      @backend = nil
    end

    def self.build_backend
      return LogBackend.new if smsapi_token.blank?
      return LogBackend.new unless live_delivery_enabled?

      SmsapiBgBackend.new(token: smsapi_token, sender_name: sender_name)
    end

    # Real SMS delivery is enabled automatically in production. In any other
    # environment it must be opted in to via SMS_LIVE=1 so dev/test runs never
    # accidentally hit the provider (or your wallet).
    def self.live_delivery_enabled?
      return true if Rails.env.production?
      ENV["SMS_LIVE"] == "1"
    end

    def self.smsapi_token
      Rails.application.credentials.dig(:smsapi_bg, :token) || ENV["SMSAPI_BG_TOKEN"]
    end

    def self.sender_name
      Rails.application.credentials.dig(:smsapi_bg, :sender) ||
        ENV["SMSAPI_BG_SENDER"]
    end
  end
end
