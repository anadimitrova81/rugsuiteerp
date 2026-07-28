class AddLocaleToInvoices < ActiveRecord::Migration[8.1]
  def change
    # Locale to render the invoice PDF in (the recipient's language), captured
    # at issue time. The platform console overrides this to Bulgarian.
    add_column :invoices, :locale, :string
  end
end
