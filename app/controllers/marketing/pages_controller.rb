class Marketing::PagesController < ActionController::Base
  # Marketing pages are never scoped to a tenant. Inheriting directly from
  # ActionController::Base (not ApplicationController) means the
  # `set_current_tenant_through_filter` / `resolve_current_factory` chain never
  # runs — so accidental tenant-scoped queries from marketing views would
  # raise via the strict acts_as_tenant initializer, which is exactly the
  # safety net we want.
  allow_browser versions: :modern

  layout "marketing"

  def home
  end
end
