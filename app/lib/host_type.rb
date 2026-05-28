module HostType
  # Reserved subdomains that are never a tenant — the app's own marketing
  # hostnames plus the conventional infrastructure prefixes.
  RESERVED_SUBDOMAINS = %w[rugsuiteerp rugsuite www app api].freeze

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

  # A "marketing host" is the apex / no-subdomain hostname or any of the
  # reserved subdomains. These should serve the SaaS marketing site, not a
  # tenant app.
  def marketing?(request)
    sub = extract_subdomain(request)
    sub.nil? || RESERVED_SUBDOMAINS.include?(sub)
  end

  def tenant?(request)
    !marketing?(request)
  end
end
