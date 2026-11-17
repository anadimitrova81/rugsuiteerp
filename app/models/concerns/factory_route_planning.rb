# Where a company's couriers start and end their day (the depot) and a rough
# coordinate per service city, used by the route planner whenever a stop has
# no pinned location. Both used to be hardcoded to the original Plovdiv-area
# factory for every company.
#
# The depot is set in Settings → Pickup, either as an address (geocoded in
# the company's country) or pasted as "lat,lng" from Google Maps. City
# coordinates are geocoded when the service area changes; a city Google
# can't find simply has none, and its stops fall back to the depot.
module FactoryRoutePlanning
  extend ActiveSupport::Concern

  included do
    validate :depot_must_be_locatable, if: -> { will_save_change_to_depot_address? && depot_address.present? }
    before_save :clear_depot_coordinates, if: -> { will_save_change_to_depot_address? && depot_address.blank? }
    # Also fills in cities still missing a coordinate (companies created before
    # this setting existed, or saved while no geocoding key was configured).
    before_save :refresh_city_coordinates,
                if: -> { will_save_change_to_service_cities? || will_save_change_to_country_code? ||
                         (service_cities - city_coordinates.keys).any? }
  end

  def depot_coordinates
    [ depot_latitude.to_f, depot_longitude.to_f ] if depot_latitude.present? && depot_longitude.present?
  end

  def depot_configured? = depot_coordinates.present?

  # A stop's fallback location when it has no pin: its city's coordinate.
  def coordinates_for_city(city)
    coords = city_coordinates[city.to_s]
    coords.map(&:to_f) if coords.is_a?(Array) && coords.size == 2
  end

  # The point routes start from and return to: the depot, or — until one is
  # set — the middle of the service area, so the planner still works.
  def route_origin
    depot_coordinates || begin
      points = city_coordinates.values.select { |c| c.is_a?(Array) && c.size == 2 }
      [ points.sum { |c| c[0].to_f } / points.size, points.sum { |c| c[1].to_f } / points.size ] if points.any?
    end
  end

  # Geocodes any service city that has no coordinate yet and drops the ones no
  # longer served. Safe to call again (e.g. after adding an API key).
  def refresh_city_coordinates
    known = (city_coordinates || {}).slice(*service_cities)
    known = {} if will_save_change_to_country_code? && persisted?
    service_cities.each do |city|
      next if known[city]

      result = Google::Geocoder.find(address: city, city: nil, country: country_code, language: default_locale)
      known[city] = [ result.latitude.to_f, result.longitude.to_f ] if result&.latitude
    end
    self.city_coordinates = known
  end

  private

  # A pasted "lat,lng" is used as-is; anything else is geocoded in the
  # company's country.
  def depot_must_be_locatable
    if depot_address.match?(ApplicationHelper::COORDINATES_REGEX)
      lat, lng = depot_address.split(",").map { |v| v.strip.to_f }
      if lat.abs > 90 || lng.abs > 180
        errors.add(:depot_address, :invalid)
      else
        self.depot_latitude, self.depot_longitude = lat, lng
      end
      return
    end

    result = Google::Geocoder.find(address: depot_address, city: nil, country: country_code, language: default_locale)
    if result&.latitude
      self.depot_latitude = result.latitude
      self.depot_longitude = result.longitude
    else
      errors.add(:depot_address, I18n.t("admin.settings.errors.depot_not_found"))
    end
  end

  def clear_depot_coordinates
    self.depot_latitude = nil
    self.depot_longitude = nil
  end
end
