class AddBrandColorsToFactories < ActiveRecord::Migration[8.1]
  def change
    add_column :factories, :brand_primary_color,   :string
    add_column :factories, :brand_secondary_color, :string
  end
end
