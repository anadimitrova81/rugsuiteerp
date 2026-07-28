require "net/http"
require "json"

# reCAPTCHA v3 verification for the marketing site. Mirrors the logic
# RequestsController uses on the tenant booking form, generalised with an
# `action:` argument. Self-contained so it can be included in
# Marketing::BaseController, which inherits ActionController::Base directly
# (not ApplicationController, where the tenant-side helpers live).
module RecaptchaVerification
  extend ActiveSupport::Concern

  RECAPTCHA_VERIFY_URL = "https://www.google.com/recaptcha/api/siteverify".freeze
  RECAPTCHA_MIN_SCORE  = 0.5

  private

  def recaptcha_site_key
    Rails.application.credentials.dig(:recaptcha, :site_key) || ENV["RECAPTCHA_SITE_KEY"]
  end

  def recaptcha_secret_key
    Rails.application.credentials.dig(:recaptcha, :secret_key) || ENV["RECAPTCHA_SECRET_KEY"]
  end

  # Returns true when Google confirms the token. `action` and `score` are
  # v3-only fields — Enterprise and v2 keys omit them, so we enforce them only
  # when Google actually returns an action (otherwise a valid Enterprise verify
  # would be rejected for missing v3 metadata).
  def verify_recaptcha(token, action:)
    if token.blank?
      Rails.logger.warn("[recaptcha] empty token")
      return false
    end

    response = Net::HTTP.post_form(
      URI(RECAPTCHA_VERIFY_URL),
      secret: recaptcha_secret_key,
      response: token,
      remoteip: request.remote_ip,
    )
    payload = JSON.parse(response.body)

    ok = payload["success"] == true
    if ok && payload["action"]
      ok = payload["action"] == action && payload["score"].to_f >= RECAPTCHA_MIN_SCORE
    end

    unless ok
      Rails.logger.warn(
        "[recaptcha] verification rejected: " \
        "success=#{payload["success"].inspect} " \
        "action=#{payload["action"].inspect} (expected #{action.inspect}) " \
        "score=#{payload["score"].inspect} (min #{RECAPTCHA_MIN_SCORE}) " \
        "hostname=#{payload["hostname"].inspect} " \
        "errors=#{payload["error-codes"].inspect}",
      )
    end
    ok
  rescue StandardError => e
    Rails.logger.warn("[recaptcha] verification raised: #{e.class} #{e.message}")
    false
  end
end
