# The route planner's start/end point and per-city coordinates used to be
# hardcoded to the original Plovdiv-area factory (с. Труд) for every company.
# They become company settings: the depot is set in Settings → Pickup, and a
# coordinate per service city is geocoded when the service area changes.
class AddDepotAndCityCoordinatesToFactories < ActiveRecord::Migration[8.1]
  # The values that were hardcoded in Routes::DailyRouteOptimizer.
  LEGACY_DEPOT = { address: "с. Труд, ул. Карловско шосе 54A", lat: 42.2189958, lng: 24.7289106 }.freeze
  LEGACY_CITIES = {
    "Пловдив" => [42.1454, 24.7497], "Асеновград" => [42.0117, 24.8740],
    "Брани поле" => [42.0683, 24.6489], "Брестник" => [42.0950, 24.7783],
    "Брестовица" => [42.0656, 24.6094], "Войводиново" => [42.2042, 24.7700],
    "Злати трап" => [42.1408, 24.5694], "Йоаким Груево" => [42.0953, 24.5825],
    "Крумово" => [42.0792, 24.7878], "Марково" => [42.0903, 24.6697],
    "Перущица" => [42.0508, 24.5547], "Първенец" => [42.0794, 24.6569],
    "Строево" => [42.1875, 24.6253], "Труд" => [42.2222, 24.7256],
    "Храбрино" => [42.0233, 24.6303], "Цалапица" => [42.1872, 24.5467],
  }.freeze

  class MigrationFactory < ActiveRecord::Base
    self.table_name = "factories"
  end

  def up
    add_column :factories, :depot_address, :string
    add_column :factories, :depot_latitude, :decimal, precision: 9, scale: 6
    add_column :factories, :depot_longitude, :decimal, precision: 9, scale: 6
    add_column :factories, :city_coordinates, :jsonb, null: false, default: {}

    # Companies whose service area is the original Plovdiv-area one (e.g. the
    # demo) keep routing exactly as before. Everyone else sets a depot.
    MigrationFactory.reset_column_information
    MigrationFactory.find_each do |factory|
      known = LEGACY_CITIES.slice(*Array(factory.service_cities))
      next if known.empty?

      factory.update_columns(
        depot_address: LEGACY_DEPOT[:address],
        depot_latitude: LEGACY_DEPOT[:lat],
        depot_longitude: LEGACY_DEPOT[:lng],
        city_coordinates: known,
      )
    end
  end

  def down
    remove_column :factories, :city_coordinates
    remove_column :factories, :depot_longitude
    remove_column :factories, :depot_latitude
    remove_column :factories, :depot_address
  end
end
