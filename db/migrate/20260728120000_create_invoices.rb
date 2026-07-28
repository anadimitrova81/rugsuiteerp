class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :factory, null: false, foreign_key: true
      # Human-facing sequential number (e.g. INV-000123). Assigned right after
      # insert from the record id, so it's nullable at the DB level but always
      # populated on committed rows.
      t.string  :number
      t.string  :plan,         null: false
      t.integer :amount_cents, null: false, default: 0
      t.string  :currency,     null: false, default: "EUR"
      t.date    :period_start, null: false
      t.date    :period_end,   null: false
      t.string  :status,       null: false, default: "issued"
      t.date    :issued_on,    null: false

      t.timestamps
    end

    add_index :invoices, :number, unique: true
    add_index :invoices, [ :factory_id, :period_start ]
  end
end
