require "net/http"
require "json"

module Google
  # Wrapper around Google's Routes API v2 — the modern replacement for the
  # legacy Directions API.
  # https://developers.google.com/maps/documentation/routes
  # https://developers.google.com/maps/documentation/routes/reference/rest/v2/TopLevel/computeRoutes
  #
  # Used to (a) compute the optimal stop order via optimizeWaypointOrder
  # and (b) report real driving distance + duration as opposed to our
  # straight-line Haversine fallback.
  #
  # The factory (::Routes::DailyRouteOptimizer::DEPOT coordinates) is always
  # origin AND destination — the courier starts and ends every route there.
  # See depot_waypoint for why we send coordinates, not the address string.
  #
  # ⚠ The API key (credentials:google_maps:directions_api_key) must have
  # "Routes API" enabled in the Google Cloud Console — it's a separate
  # product from the legacy Directions API even though the same key can
  # serve both.
  module Routes
    ENDPOINT = "https://routes.googleapis.com/directions/v2:computeRoutes".freeze
    FIELD_MASK = "routes.duration,routes.distanceMeters,routes.optimizedIntermediateWaypointIndex".freeze

    Result = Struct.new(:ordered_stops, :distance_km, :total_minutes, keyword_init: true)

    # Returns the optimal order plus distance/time.
    def self.optimize(stops:)
      request_route(stops: stops, optimize: true)
    end

    # Returns distance/time for the given order (no reordering).
    def self.calculate(stops:)
      request_route(stops: stops, optimize: false)
    end

    def self.request_route(stops:, optimize:)
      return nil if stops.empty?
      return nil unless api_key.present?

      body = {
        origin:      depot_waypoint,
        destination: depot_waypoint,
        intermediates: stops.map { |s| waypoint_for(s) },
        travelMode: "DRIVE",
        routingPreference: "TRAFFIC_AWARE",
        languageCode: "bg",
      }
      body[:optimizeWaypointOrder] = true if optimize

      response = http_post(URI(ENDPOINT), body)
      payload = JSON.parse(response.body) rescue {}

      unless response.is_a?(Net::HTTPSuccess) && payload["routes"]&.any?
        Rails.logger.warn(
          "[google_routes] non-OK status=#{response.code} " \
          "error=#{payload.dig("error", "message").inspect} " \
          "body=#{response.body.to_s[0, 200]}",
        )
        return nil
      end

      route = payload["routes"].first
      order = route["optimizedIntermediateWaypointIndex"] || (0...stops.size).to_a
      meters = route["distanceMeters"].to_i
      # "duration" comes back as "Ns" (e.g. "1234s") per protobuf Duration encoding.
      seconds = route["duration"].to_s.delete_suffix("s").to_i

      Result.new(
        ordered_stops: order.map { |i| stops[i] },
        distance_km: (meters / 1000.0).round(1),
        total_minutes: (seconds / 60.0).round,
      )
    rescue StandardError => e
      Rails.logger.warn("[google_routes] request failed: #{e.class} #{e.message}")
      nil
    end

    # The depot is always origin and destination. We send its coordinates
    # rather than DEPOT_ADDRESS: the address string ("с. Труд, …") fails the
    # Routes API geocoder ("Address not found"), which silently yields an empty
    # response and no route. Coordinates always resolve.
    def self.depot_waypoint
      lat, lng = ::Routes::DailyRouteOptimizer::DEPOT
      { location: { latLng: { latitude: lat, longitude: lng } } }
    end

    # Builds a Routes-API Waypoint for a Request. If the coordinator pasted a
    # Google Maps pin (verified_address = "lat,lng"), we send those coords;
    # otherwise we send the address text and let Google geocode it — much
    # better than collapsing every stop to a city centroid.
    def self.waypoint_for(request)
      if request.verified_address.to_s.match?(ApplicationHelper::COORDINATES_REGEX)
        lat, lng = request.verified_address.split(",").map(&:to_f)
        { location: { latLng: { latitude: lat, longitude: lng } } }
      else
        address = [request.address, request.city].compact_blank.join(", ")
        if address.present?
          { address: address }
        else
          { address: ::Routes::DailyRouteOptimizer::DEPOT_ADDRESS }
        end
      end
    end

    def self.api_key
      # Prefer a Routes-API-specific key so we can scope it tighter in Google
      # Cloud Console (Routes API only, no Geocoding/Maps JS, no Directions).
      # Falls back to the legacy directions/geocoding key so older envs still
      # work — but those need Routes API enabled to actually succeed.
      Rails.application.credentials.dig(:google_maps, :routes_api_key) ||
        Rails.application.credentials.dig(:google_maps, :directions_api_key) ||
        Rails.application.credentials.dig(:google_maps, :geocoding_api_key) ||
        ENV["GOOGLE_ROUTES_API_KEY"] ||
        ENV["GOOGLE_DIRECTIONS_API_KEY"]
    end

    def self.http_post(uri, body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 12

      req = Net::HTTP::Post.new(uri.request_uri)
      req["Content-Type"] = "application/json"
      req["X-Goog-Api-Key"] = api_key
      req["X-Goog-FieldMask"] = FIELD_MASK
      req.body = JSON.generate(body)
      http.request(req)
    end
  end
end
