class AddVoucherToRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :voucher, :boolean, default: false, null: false
  end
end
