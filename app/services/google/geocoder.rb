require "net/http"
require "json"

module Google
  # Thin wrapper around Google's Geocoding API.
  # https://developers.google.com/maps/documentation/geocoding/overview
  module Geocoder
    ENDPOINT = "https://maps.googleapis.com/maps/api/geocode/json".freeze
    CACHE_TTL = 1.hour

    Result = Struct.new(:formatted_address, :latitude, :longitude, :place_id, keyword_init: true)

    # Returns Result on success, nil if Google can't resolve the address.
    # Constrained to Bulgaria via `components=country:BG` so a wrong city like
    # "Berlin" doesn't accidentally match.
    def self.find(address:, city:)
      return nil unless api_key.present?
      return nil if address.blank?

      query = [address, city].compact_blank.join(", ")
      cache_key = "geocoder/v1/#{Digest::SHA1.hexdigest(query.downcase)}"

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        request_geocode(query)
      end
    end

    def self.api_key
      Rails.application.credentials.dig(:google_maps, :geocoding_api_key) ||
        ENV["GOOGLE_GEOCODING_API_KEY"]
    end

    def self.request_geocode(query)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(
        address: query,
        components: "country:BG",
        language: "bg",
        key: api_key,
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 4
      http.read_timeout = 6

      response = http.request(Net::HTTP::Get.new(uri.request_uri))
      payload = JSON.parse(response.body) rescue {}

      case payload["status"]
      when "OK"
        result = payload["results"].first
        loc = result.dig("geometry", "location") || {}
        Result.new(
          formatted_address: result["formatted_address"],
          latitude: loc["lat"],
          longitude: loc["lng"],
          place_id: result["place_id"],
        )
      when "ZERO_RESULTS"
        nil
      else
        Rails.logger.warn("[geocoder] non-OK status=#{payload["status"]} message=#{payload["error_message"]}")
        nil
      end
    rescue StandardError => e
      Rails.logger.warn("[geocoder] request failed: #{e.class} #{e.message}")
      nil
    end
  end
end
