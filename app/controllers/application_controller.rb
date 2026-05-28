class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  set_current_tenant_through_filter
  before_action :resolve_current_factory
  around_action :switch_locale

  helper_method :current_admin, :admin_logged_in?, :recaptcha_site_key, :true_admin, :impersonating?, :current_factory

  class FactoryNotFound < StandardError; end
  rescue_from FactoryNotFound, with: :render_factory_not_found

  private

  def current_factory
    ActsAsTenant.current_tenant
  end

  def resolve_current_factory
    factory = Factory.find_by(slug: tenant_slug)
    raise FactoryNotFound if factory.nil?
    set_current_tenant(factory)
  end

  # Switch I18n.locale to the factory's chosen language for the duration of the
  # request. Falls back to the global default if the factory's locale isn't in
  # the available list (avoids `I18n::InvalidLocale` if a stale value lands in
  # the DB).
  def switch_locale(&action)
    locale = current_factory&.default_locale&.to_sym
    locale = I18n.default_locale unless I18n.available_locales.include?(locale)
    I18n.with_locale(locale, &action)
  end

  # Pull the tenant slug from the leftmost subdomain (e.g. acme.rugsuite.app → "acme").
  # In development we accept a ?factory= override and fall back to the seeded
  # "default" tenant so the app remains usable on http://localhost:3000.
  def tenant_slug
    sub = HostType.extract_subdomain(request)
    sub = nil if HostType::RESERVED_SUBDOMAINS.include?(sub)

    return sub if sub.present?

    if Rails.env.development? || Rails.env.test?
      return params[:factory].to_s.downcase.presence || "default"
    end

    nil
  end

  def render_factory_not_found
    render plain: "Unknown factory", status: :not_found
  end

  def current_admin
    @current_admin ||= User.find_by(id: session[:admin_id]) if session[:admin_id]
  end

  def admin_logged_in?
    current_admin.present?
  end

  def true_admin
    return current_admin unless session[:true_admin_id]
    @true_admin ||= User.find_by(id: session[:true_admin_id]) || current_admin
  end

  def impersonating?
    session[:true_admin_id].present? && current_admin.present? && current_admin.id != session[:true_admin_id]
  end

  def recaptcha_site_key
    Rails.application.credentials.dig(:recaptcha, :site_key) || ENV["RECAPTCHA_SITE_KEY"]
  end

  def require_admin
    unless admin_logged_in?
      redirect_to login_path, alert: "Трябва да сте влезли, за да достъпите тази страница."
    end
  end
end
