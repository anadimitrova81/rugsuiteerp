class CreateFactories < ActiveRecord::Migration[8.1]
  def change
    create_table :factories do |t|
      t.string :slug, null: false
      t.string :name, null: false

      # Locale / region defaults
      t.string :country_code, null: false, limit: 2
      t.string :timezone, null: false, default: "UTC"
      t.string :currency, null: false, limit: 3, default: "EUR"
      t.string :default_locale, null: false, limit: 8, default: "en"
      t.string :phone_country, null: false, limit: 2

      # Per-tenant pricing (was hardcoded in Request)
      t.decimal :price_per_kg,          precision: 10, scale: 2, null: false, default: 0
      t.decimal :price_per_kg_bulk,     precision: 10, scale: 2, null: false, default: 0
      t.decimal :bulk_weight_threshold, precision: 10, scale: 2, null: false, default: 0
      t.decimal :price_per_item,        precision: 10, scale: 2, null: false, default: 0

      # Per-tenant scheduling
      t.integer :same_day_cutoff_hour, null: false, default: 16

      # Cities/areas the factory services
      t.jsonb :service_cities, null: false, default: []

      t.timestamps
    end

    add_index :factories, :slug, unique: true
  end
end
