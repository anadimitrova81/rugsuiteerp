require "net/http"
require "json"

module Sms
  # SMSAPI.bg HTTP delivery backend.
  # Docs: https://www.smsapi.bg/docs/ — POST /sms.do with bearer token auth.
  class SmsapiBgBackend
    ENDPOINT = "https://api.smsapi.bg/sms.do".freeze

    def initialize(token:, sender_name: nil)
      @token = token
      @sender_name = sender_name
    end

    def deliver(to:, body:)
      uri = URI(ENDPOINT)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{@token}"
      form_data = { to: to, message: body, format: "json", encoding: "utf-8" }
      form_data[:from] = @sender_name if @sender_name.present?
      request.set_form_data(form_data)

      response = http.request(request)
      payload = JSON.parse(response.body) rescue {}

      if response.is_a?(Net::HTTPSuccess) && payload["error"].nil?
        true
      else
        raise Sender::DeliveryError, "SMSAPI.bg delivery failed (status=#{response.code} body=#{response.body.to_s[0, 200]})"
      end
    end
  end
end
