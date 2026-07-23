require "cgi"

module Platform
  # Mints a signed, short-lived token and redirects the operator to the tenant
  # subdomain, where PlatformHandoffsController establishes the impersonated
  # session. The session cookie is host-scoped, so a token hand-off is the only
  # way to carry auth across subdomains.
  class ImpersonationsController < BaseController
    def create
      factory = Factory.find(params[:id])
      user = ActsAsTenant.with_tenant(factory) { User.find(params[:user_id]) }

      token = Rails.application.message_verifier(:platform_impersonation).generate(
        { "user_id" => user.id, "factory_id" => factory.id, "platform_admin_id" => current_platform_admin.id },
        expires_in: 60.seconds,
        purpose: :impersonation,
      )

      Rails.logger.info(
        "[platform] impersonation minted operator=#{current_platform_admin.email} " \
        "target_user=#{user.id} factory=#{factory.slug}",
      )

      redirect_to enter_url(factory.slug, token), allow_other_host: true
    end

    private

    def enter_url(slug, token)
      host = HostType.tenant_host(request.host, slug)
      port = [ 80, 443 ].include?(request.port) ? "" : ":#{request.port}"
      "#{request.scheme}://#{host}#{port}/enter?token=#{CGI.escape(token)}"
    end
  end
end
