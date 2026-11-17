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
    # Constrained to the company's country (`components=country:XX`) so a
    # wrong city like "Berlin" doesn't accidentally match. Country and
    # language default to the current tenant's.
    def self.find(address:, city:, country: nil, language: nil)
      return nil unless api_key.present?
      return nil if address.blank?

      tenant = ActsAsTenant.current_tenant
      country = (country || tenant&.country_code).to_s.upcase.presence
      language = (language || tenant&.default_locale).to_s.presence

      query = [address, city].compact_blank.join(", ")
      cache_key = "geocoder/v3/#{country}/#{language}/#{Digest::SHA1.hexdigest(query.downcase)}"

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        request_geocode(query, country: country, language: language)
      end
    end

    def self.api_key
      Rails.application.credentials.dig(:google_maps, :geocoding_api_key) ||
        ENV["GOOGLE_GEOCODING_API_KEY"]
    end

    def self.request_geocode(query, country:, language:)
      uri = URI(ENDPOINT)
      params = { address: query, key: api_key }
      params[:components] = "country:#{country}" if country
      params[:language] = language if language
      uri.query = URI.encode_www_form(params)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 4
      http.read_timeout = 6

      response = http.request(Net::HTTP::Get.new(uri.request_uri))
      payload = JSON.parse(response.body) rescue {}

      case payload["status"]
      when "OK"
        result = payload["results"].first
        # With nothing better, Google answers with the whole country
        # ("United Kingdom") — that isn't a location we can route or
        # validate against.
        return nil if Array(result["types"]).include?("country")

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
