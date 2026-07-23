# Rack::Attack rate limiting. Uses Rails.cache (Solid Cache in prod) as the
# backing store, so throttle counts persist across Puma workers but reset on
# deploy. Limits are intentionally generous — they cap abuse, not real users.

class Rack::Attack
  # 5 failed login attempts per minute per IP. Successful logins don't count
  # because Rails returns a 302 redirect and we only throttle the POST.
  throttle("logins/ip", limit: 5, period: 60.seconds) do |req|
    req.ip if req.post? && req.path == "/login"
  end

  # 30 customer order lookups per minute per IP. Covers both the SMS
  # short-link (/r/:token) and the manual phone-lookup page (/status).
  # An honest customer will never come close.
  throttle("status_lookups/ip", limit: 30, period: 60.seconds) do |req|
    req.ip if req.path.start_with?("/r/") || req.path == "/status"
  end

  # 5 new order submissions per hour per IP. reCAPTCHA is the first line of
  # defense; this is the second.
  throttle("orders/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/requests"
  end

  # Custom response for throttled requests — kept short so a tripped real user
  # isn't completely lost. Uses the default locale (per-request locale isn't
  # resolved yet this early in the stack).
  self.throttled_responder = lambda do |_env|
    [ 429, { "Content-Type" => "text/plain; charset=utf-8", "Retry-After" => "60" },
     [ I18n.t("rack_attack.too_many_requests") ], ]
  end
end
