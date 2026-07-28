class AddBillingDetailsToFactories < ActiveRecord::Migration[8.1]
  def change
    # Legal billing identity of the tenant company, collected when it upgrades
    # to a paid plan and snapshotted onto each invoice (получател / recipient).
    add_column :factories, :billing_company_name, :string
    add_column :factories, :billing_address,      :text
    add_column :factories, :billing_eik,          :string   # ЕИК/Булстат
    add_column :factories, :billing_vat_number,   :string   # ДДС № (optional)
    add_column :factories, :billing_mol,          :string   # МОЛ
  end
end
