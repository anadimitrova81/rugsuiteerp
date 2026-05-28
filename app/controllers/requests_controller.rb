require "net/http"
require "json"

class RequestsController < ApplicationController
  include TracksPublicVisits

  RECAPTCHA_VERIFY_URL = "https://www.google.com/recaptcha/api/siteverify".freeze
  RECAPTCHA_MIN_SCORE = 0.5
  RECAPTCHA_ACTION = "request_create".freeze

  before_action :redirect_logged_in_users

  def new
    @request = Request.new
  end

  def show
    @request = Request.find(params[:id])
  end

  def create
    @request = Request.new(request_params)

    if recaptcha_secret_key.blank?
      Rails.logger.warn("[recaptcha] secret key not configured, skipping verification")
    elsif !verify_recaptcha(params[:"g-recaptcha-response"])
      flash.now[:alert] = "Не успяхме да потвърдим, че сте човек. Моля, опитайте отново."
      render :new, status: :unprocessable_entity and return
    end

    if @request.save
      redirect_to @request
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_logged_in_users
    redirect_to admin_requests_path if admin_logged_in?
  end

  def request_params
    params.
      require(:request).
      permit(:phone, :city, :address, :pick_up_at, :pick_up_notes)
  end

  def verify_recaptcha(token)
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

    # success is the baseline. action/score are v3-only fields — Enterprise
    # and v2 keys don't return them, so we only enforce them when present
    # (otherwise every Enterprise verify would be rejected as missing v3
    # metadata even though Google said the token is valid).
    ok = payload["success"] == true
    if ok && payload["action"]
      ok = payload["action"] == RECAPTCHA_ACTION &&
           payload["score"].to_f >= RECAPTCHA_MIN_SCORE
    end

    unless ok
      Rails.logger.warn(
        "[recaptcha] verification rejected: " \
        "success=#{payload["success"].inspect} " \
        "action=#{payload["action"].inspect} (expected #{RECAPTCHA_ACTION.inspect}) " \
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

  def recaptcha_secret_key
    Rails.application.credentials.dig(:recaptcha, :secret_key) || ENV["RECAPTCHA_SECRET_KEY"]
  end
end
