require "net/http"
require "json"

class RequestsController < ApplicationController
  include TracksPublicVisits

  before_action :redirect_logged_in_users
  before_action :enforce_order_limit, only: %i[new create]

  def new
    @request = Request.new
  end

  def show
    @request = Request.find(params[:id])
  end

  def create
    @request = Request.new(request_params)

    if turnstile_secret_key.blank?
      Rails.logger.warn("[turnstile] secret key not configured, skipping verification")
    elsif !verify_turnstile(params[:"cf-turnstile-response"])
      flash.now[:alert] = t("requests.captcha_failed")
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

  # When the factory has hit its plan's monthly order cap, stop taking new
  # online orders. Clients get a neutral "call us" message rather than any
  # billing detail (that's the factory's concern, not the customer's).
  def enforce_order_limit
    return unless current_factory.order_limit_reached?

    redirect_to root_path, alert: t("requests.order_limit_reached")
  end

  def request_params
    params.
      require(:request).
      permit(:phone, :city, :address, :pick_up_at, :pick_up_notes)
  end
end
