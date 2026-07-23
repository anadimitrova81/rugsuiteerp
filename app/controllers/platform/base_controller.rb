module Platform
  # Base for the platform operator console at admin.rugsuiteerp.com. Inherits
  # ActionController::Base directly (NOT ApplicationController) so the tenant
  # filter never runs — this console spans every factory. Auth is a PlatformAdmin
  # session, entirely separate from tenant User sessions (and on a different host,
  # so the cookies never mix).
  class BaseController < ActionController::Base
    allow_browser versions: :modern
    layout "platform"

    before_action :require_platform_admin
    helper_method :current_platform_admin

    private

    def current_platform_admin
      return unless session[:platform_admin_id]
      @current_platform_admin ||= PlatformAdmin.find_by(id: session[:platform_admin_id])
    end

    def require_platform_admin
      redirect_to platform_login_path unless current_platform_admin
    end
  end
end
