class AddPricingModeAndSqmToFactories < ActiveRecord::Migration[8.1]
  def change
    add_column :factories, :pricing_mode, :string, null: false, default: "per_kg"
    add_column :factories, :price_per_sqm,        :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :factories, :price_per_sqm_bulk,   :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :factories, :bulk_area_threshold,  :decimal, precision: 10, scale: 2, null: false, default: 0
  end
end
