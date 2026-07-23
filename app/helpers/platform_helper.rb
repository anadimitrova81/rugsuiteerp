module PlatformHelper
  # Public URL for a tenant's site, derived from the current (platform) request
  # host — dev localhost/lvh.me or the apex domain with the slug swapped in.
  def tenant_site_url(factory, path: "/")
    host = HostType.tenant_host(request.host, factory.slug)
    port = [ 80, 443 ].include?(request.port) ? "" : ":#{request.port}"
    "#{request.scheme}://#{host}#{port}#{path}"
  end
end
