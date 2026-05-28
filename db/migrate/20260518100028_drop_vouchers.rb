class DropVouchers < ActiveRecord::Migration[8.1]
  # Drops the vouchers feature in three steps so envs apply it idempotently:
  #   1. Drop the FK on requests.voucher_id so we can free the column.
  #   2. Drop the four voucher_* columns from requests.
  #   3. Drop the vouchers table.
  def up
    remove_foreign_key :requests, :vouchers, if_exists: true

    %i[voucher_id voucher_count voucher_received voucher_source].each do |column|
      remove_column :requests, column, if_exists: true
    end

    drop_table :vouchers, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Vouchers were retired; restore from db/migrate/20260513120002_create_vouchers.rb if you really need them back."
  end
end
