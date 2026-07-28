class AddRecipientCountryToInvoices < ActiveRecord::Migration[8.1]
  def change
    # ISO country code of the recipient at issue time, so the PDF labels the
    # legal identifiers (ЕИК vs SIREN vs VKN …) correctly for historical rows.
    add_column :invoices, :recipient_country_code, :string
  end
end
