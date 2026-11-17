# Each order stores the per-kg rate it was priced at, so a later price change
# in the company settings never rewrites existing orders.
class AddPricePerKgToRequests < ActiveRecord::Migration[8.1]
  def up
    add_column :requests, :price_per_kg, :decimal, precision: 10, scale: 2

    # Existing orders keep the rate they were actually billed at.
    execute <<~SQL
      UPDATE requests SET price_per_kg = ROUND(amount / weight, 2)
      WHERE weight > 0 AND amount IS NOT NULL
    SQL
  end

  def down
    remove_column :requests, :price_per_kg
  end
end
