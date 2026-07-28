module HostType
  # The platform operator console (all tenants, cross-tenant impersonation).
  PLATFORM_SUBDOMAIN = "admin".freeze

  # Reserved subdomains that are never a tenant — the app's own marketing
  # hostnames plus the conventional infrastructure prefixes. Includes the
  # platform console subdomain so it's never mistaken for a factory slug.
  RESERVED_SUBDOMAINS = %w[rugsuiteerp rugsuite www app api admin].freeze

  module_function

  # Returns the leftmost subdomain treating `.localhost` and `.lvh.me` as
  # dev-only TLDs (so `acme.localhost` → "acme") in addition to the standard
  # `request.subdomains` behaviour.
  def extract_subdomain(request)
    host = request.host.to_s.downcase
    if host.end_with?(".localhost") || host.end_with?(".lvh.me")
      host.split(".").first.presence
    else
      request.subdomains.first&.downcase.presence
    end
  end

  # The platform operator console at admin.rugsuiteerp.com. Not a tenant and not
  # the marketing site — it spans every factory.
  def platform?(request)
    extract_subdomain(request) == PLATFORM_SUBDOMAIN
  end

  # A "marketing host" is the apex / no-subdomain hostname or any of the
  # reserved subdomains (except the platform console). These serve the SaaS
  # marketing site, not a tenant app.
  def marketing?(request)
    return false if platform?(request)
    sub = extract_subdomain(request)
    sub.nil? || RESERVED_SUBDOMAINS.include?(sub)
  end

  def tenant?(request)
    !platform?(request) && !marketing?(request)
  end

  # The host a given tenant `slug` is served on, derived from the current
  # request host: `<slug>.localhost` / `<slug>.lvh.me` in dev, otherwise the
  # apex domain with the leftmost label replaced by the slug
  # (e.g. from admin.rugsuiteerp.com → acme.rugsuiteerp.com). Used to build
  # cross-subdomain redirects (signup landing, platform impersonation).
  # The platform console host that is a sibling of the current host: replaces
  # the leftmost subdomain label with the platform subdomain. From any tenant
  # host `<slug>.rugsuiteerp.com` (or `<slug>.rugsuiteerp.localhost` in dev) it
  # returns `admin.rugsuiteerp.com` — unlike `tenant_host`, it doesn't care
  # whether the leftmost label is a reserved subdomain.
  def platform_host(request_host)
    labels = request_host.to_s.downcase.split(".")
    labels.shift if labels.size > 2 # drop the tenant slug, keep the base domain
    "#{PLATFORM_SUBDOMAIN}.#{labels.join('.')}"
  end

  def tenant_host(request_host, slug)
    host = request_host.to_s.downcase
    if host.end_with?(".localhost") || host == "localhost"
      "#{slug}.localhost"
    elsif host.end_with?(".lvh.me") || host == "lvh.me"
      "#{slug}.lvh.me"
    else
      parts = host.split(".")
      parts.shift if RESERVED_SUBDOMAINS.include?(parts.first)
      "#{slug}.#{parts.join('.')}"
    end
  end
end
