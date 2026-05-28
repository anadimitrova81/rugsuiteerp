class AddBulkPriceToRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :bulk_price, :boolean, default: false, null: false
  end
end
