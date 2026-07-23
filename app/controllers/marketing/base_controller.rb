module Marketing
  # Shared base for the SaaS marketing site (apex / reserved-subdomain hosts).
  # Inherits ActionController::Base directly — NOT ApplicationController — so the
  # tenant filter chain (`set_current_tenant_through_filter` /
  # `resolve_current_factory`) never runs; a stray tenant-scoped query from a
  # marketing view then raises via the strict acts_as_tenant initializer, which
  # is the safety net we want.
  class BaseController < ActionController::Base
    allow_browser versions: :modern

    layout "marketing"

    around_action :switch_locale

    private

    # The marketing site isn't tenant-scoped, so locale comes from an explicit
    # ?locale= choice (validated, then remembered in the session), else the
    # visitor's remembered choice, else the global default.
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

      I18n.default_locale
    end
  end
end
