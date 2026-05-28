module Sms
  # No-op backend used when no SMS provider is configured.
  # Logs the would-be message so you can see what was supposed to go out.
  class LogBackend
    def deliver(to:, body:)
      Rails.logger.info("[sms:log] to=#{to} body=#{body.inspect}")
      true
    end
  end
end
