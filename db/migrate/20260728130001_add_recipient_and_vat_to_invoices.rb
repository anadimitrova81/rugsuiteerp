class AddRecipientAndVatToInvoices < ActiveRecord::Migration[8.1]
  def change
    # Recipient (получател) details snapshotted at issue time, so past invoices
    # never change if the tenant later edits its billing details.
    add_column :invoices, :recipient_name,       :string
    add_column :invoices, :recipient_address,    :text
    add_column :invoices, :recipient_eik,        :string
    add_column :invoices, :recipient_vat_number, :string
    add_column :invoices, :recipient_mol,        :string

    # VAT / discount fields for the Bulgarian фактура. Defaults match the
    # issuer's regime (not VAT-registered → 0%, чл.113 ал.9; no discount).
    add_column :invoices, :vat_rate,         :integer, null: false, default: 0
    add_column :invoices, :vat_grounds,      :string
    add_column :invoices, :discount_percent, :integer, null: false, default: 0
  end
end
