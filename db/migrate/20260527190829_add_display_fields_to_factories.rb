class AddDisplayFieldsToFactories < ActiveRecord::Migration[8.1]
  def change
    add_column :factories, :phone,           :string
    add_column :factories, :email,           :string
    add_column :factories, :legal_name,      :string
    add_column :factories, :hero_tagline,    :string
    add_column :factories, :pickup_window,   :string
    add_column :factories, :business_hours,  :string
  end
end
