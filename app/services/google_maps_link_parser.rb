require "net/http"
require "uri"
require "cgi"

# Resolves a Google Maps URL into structured address + city data.
#
# Handles the common shapes:
#   https://www.google.com/maps/place/<formatted+address>/@lat,lng,zoom
#   https://www.google.com/maps?q=<formatted+address>
#   https://www.google.com/maps?q=<lat,lng>
#   https://maps.app.goo.gl/<short>   ← followed via redirects
#   https://goo.gl/maps/<short>       ← legacy short links
#
# Pure-Ruby parsing for `/place/...` and `?q=...`. Coordinate-only links would
# require Google's Geocoding API (reverse) and are reported as unsupported when
# no API key is configured.
module GoogleMapsLinkParser
  GOOGLE_MAPS_HOSTS = %w[
    www.google.com
    maps.google.com
    google.com
  ].freeze
  SHORT_LINK_HOSTS = %w[maps.app.goo.gl goo.gl].freeze

  Result = Struct.new(:coordinates, keyword_init: true)

  def self.looks_like_link?(input)
    input.to_s.strip.start_with?("http://", "https://")
  end

  def self.parse(input)
    return nil unless looks_like_link?(input)

    url = input.to_s.strip
    expanded = SHORT_LINK_HOSTS.any? { |h| url.include?(h) } ? follow_redirects(url) : url
    return nil if expanded.blank?

    extract(expanded)
  end

  def self.extract(url)
    coords = extract_coordinates(url)
    return nil unless coords

    Result.new(coordinates: "#{coords[0]},#{coords[1]}")
  end

  def self.extract_coordinates(url)
    # 1. Pin location embedded in the data param (most reliable — this is the
    #    actual marker, not the map center): !3d<lat>!4d<lng>
    if (md = url.match(/!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)/))
      return [md[1], md[2]]
    end

    uri = safe_uri(url)
    return nil unless uri

    # 2. /@LAT,LNG[,zoom] — the map center
    if (md = uri.path.match(%r{/@(-?\d+\.\d+),(-?\d+\.\d+)}))
      return [md[1], md[2]]
    end

    # 3. ?q=LAT,LNG  /  ?ll=LAT,LNG  /  ?query=LAT,LNG
    if uri.query
      params = URI.decode_www_form(uri.query).to_h
      %w[q ll query].each do |key|
        next unless (val = params[key])
        if (md = val.match(/\A(-?\d+\.\d+),\s*(-?\d+\.\d+)\z/))
          return [md[1], md[2]]
        end
      end
    end

    nil
  end

  def self.safe_uri(url)
    URI.parse(url)
  rescue URI::InvalidURIError
    nil
  end

  def self.follow_redirects(url, limit: 5)
    return nil if limit <= 0

    uri = safe_uri(url)
    return nil unless uri

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 4, read_timeout: 6) do |http|
      http.request(Net::HTTP::Head.new(uri.request_uri, "User-Agent" => "NexusCleaning/1.0"))
    end

    if response.is_a?(Net::HTTPRedirection)
      location = response["Location"]
      location = URI.join(url, location).to_s unless location.start_with?("http")
      follow_redirects(location, limit: limit - 1)
    else
      url
    end
  rescue StandardError => e
    Rails.logger.warn("[google_maps_link_parser] redirect follow failed: #{e.class} #{e.message}")
    nil
  end
end
