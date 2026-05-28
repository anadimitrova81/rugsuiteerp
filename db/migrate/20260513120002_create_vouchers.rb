class CreateVouchers < ActiveRecord::Migration[8.1]
  def change
    create_table :vouchers do |t|
      t.string :code, null: false
      t.string :label, null: false
      t.integer :kg
      t.integer :quilts
      t.decimal :price_eur, precision: 10, scale: 2, default: 0, null: false
      t.string :payee, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :vouchers, :code, unique: true
  end
end
