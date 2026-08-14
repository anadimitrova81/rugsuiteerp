require "net/http"
require "json"

# Cloudflare Turnstile verification (replaces Google reCAPTCHA). Provides the
# site key for the client widget and server-side token verification. Included
# in both the tenant stack (ApplicationController) and the marketing site
# (Marketing::BaseController).
module TurnstileVerification
  extend ActiveSupport::Concern

  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze

  # Cloudflare's public test keys (always pass). Used in dev/test so the widget
  # works without real keys; production reads real keys from credentials.
  TEST_SITE_KEY   = "1x00000000000000000000AA".freeze
  TEST_SECRET_KEY = "1x0000000000000000000000000000000AA".freeze

  private

  def turnstile_site_key
    Rails.application.credentials.dig(:turnstile, :site_key) || ENV["TURNSTILE_SITE_KEY"] ||
      (Rails.env.local? ? TEST_SITE_KEY : nil)
  end

  def turnstile_secret_key
    Rails.application.credentials.dig(:turnstile, :secret_key) || ENV["TURNSTILE_SECRET_KEY"] ||
      (Rails.env.local? ? TEST_SECRET_KEY : nil)
  end

  # Verifies a Turnstile token with Cloudflare. Pass/fail (no score).
  def verify_turnstile(token)
    if token.blank?
      Rails.logger.warn("[turnstile] empty token")
      return false
    end

    response = Net::HTTP.post_form(
      URI(VERIFY_URL),
      secret: turnstile_secret_key,
      response: token,
      remoteip: request.remote_ip,
    )
    payload = JSON.parse(response.body)
    ok = payload["success"] == true

    unless ok
      Rails.logger.warn(
        "[turnstile] verification rejected: " \
        "errors=#{payload['error-codes'].inspect} hostname=#{payload['hostname'].inspect}",
      )
    end
    ok
  rescue StandardError => e
    Rails.logger.warn("[turnstile] verification raised: #{e.class} #{e.message}")
    false
  end
end
