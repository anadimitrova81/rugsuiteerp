class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
  # Responses vary by language, so fold the active locale into the etag —
  # otherwise a visitor switching languages could be served a 304 with the
  # previously cached translation.
  etag { I18n.locale }

  set_current_tenant_through_filter
  before_action :resolve_current_factory
  around_action :switch_locale

  helper_method :current_admin, :admin_logged_in?, :recaptcha_site_key, :true_admin, :impersonating?, :current_factory, :platform_impersonating?

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

  # Switch I18n.locale for the duration of the request. Precedence:
  #   1. an explicit ?locale= choice (validated, then remembered in the session)
  #   2. the visitor's previously remembered choice
  #   3. the factory's configured default language
  #   4. the global default
  # Every step is guarded against values outside the available list to avoid
  # `I18n::InvalidLocale` from a stale session value or DB row.
  def switch_locale(&action)
    I18n.with_locale(requested_locale, &action)
  end

  def requested_locale
    chosen = params[:locale].presence&.to_sym
    if chosen && I18n.available_locales.include?(chosen)
      session[:locale] = chosen
      return chosen
    end

    remembered = session[:locale]&.to_sym
    return remembered if remembered && I18n.available_locales.include?(remembered)

    factory_locale = current_factory&.default_locale&.to_sym
    return factory_locale if factory_locale && I18n.available_locales.include?(factory_locale)

    I18n.default_locale
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

  # A platform operator viewing a tenant via the cross-tenant impersonation
  # hand-off (distinct from same-tenant admin impersonation above).
  def platform_impersonating?
    session[:platform_impersonator_id].present? && current_admin.present?
  end

  def recaptcha_site_key
    Rails.application.credentials.dig(:recaptcha, :site_key) || ENV["RECAPTCHA_SITE_KEY"]
  end

  def require_admin
    unless admin_logged_in?
      redirect_to login_path, alert: I18n.t("admin.login.required")
    end
  end
end
