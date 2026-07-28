class Marketing::SignupsController < Marketing::BaseController
  # Marketing pages don't go through the tenant filter; FactoryProvisioner
  # handles tenant-scoped writes with `ActsAsTenant.with_tenant`.
  protect_from_forgery with: :exception

  RECAPTCHA_ACTION = "signup".freeze

  def new
    @form = FactoryProvisioner.new
  end

  def create
    # Bot gate before we provision a tenant. Skipped only when no secret key is
    # configured (e.g. dev without reCAPTCHA set up), matching the tenant form.
    if recaptcha_secret_key.present? &&
       !verify_recaptcha(params[:"g-recaptcha-response"], action: RECAPTCHA_ACTION)
      @form = FactoryProvisioner.new(signup_params)
      @form.errors.add(:base, t("requests.captcha_failed"))
      render :new, status: :unprocessable_entity and return
    end

    @form = FactoryProvisioner.call(signup_params)
    if @form.success?
      # Drop them on their tenant's home page with ?welcome=1 so the home
      # view renders the onboarding modal. They'll still need to log in once
      # when they click into the admin area — signup-side session doesn't
      # carry across to the tenant subdomain. A signed-token handoff to skip
      # that step is deferred.
      redirect_to "#{tenant_root_url(@form.factory)}?welcome=1", allow_other_host: true
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.require(:signup).permit(:name, :slug, :country_code, :admin_email, :admin_password)
  end

  def tenant_root_url(factory)
    host = request.host.to_s.downcase
    port = request.port
    port_part = ([ 80, 443 ].include?(port) ? "" : ":#{port}")
    scheme = request.ssl? ? "https" : "http"

    # In dev: foo.localhost / foo.lvh.me. In prod: foo.rugsuite.app (i.e. swap
    # the leftmost host label for the new tenant's slug).
    new_host =
      if host.end_with?(".localhost") || host == "localhost"
        "#{factory.slug}.localhost"
      elsif host.end_with?(".lvh.me") || host == "lvh.me"
        "#{factory.slug}.lvh.me"
      else
        parts = host.split(".")
        # Replace or prepend the leftmost label.
        parts.shift if HostType::RESERVED_SUBDOMAINS.include?(parts.first)
        "#{factory.slug}.#{parts.join('.')}"
      end

    "#{scheme}://#{new_host}#{port_part}/"
  end
end
