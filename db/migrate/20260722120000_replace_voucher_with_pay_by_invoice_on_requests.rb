class ReplaceVoucherWithPayByInvoiceOnRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :pay_by_invoice, :boolean, default: false, null: false
    remove_column :requests, :voucher, :boolean, default: false, null: false
  end
end
