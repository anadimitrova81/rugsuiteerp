class CreateRequests < ActiveRecord::Migration[8.1]
  def change
    create_enum :requests_status, %w[
      pending pickup_confirmed picked_up in_progress
      ready_for_delivery delivery_confirmed delivered cancelled
    ]

    create_table :requests do |t|
      # Identity / contact
      t.string :customer_id
      t.string :phone, null: false

      # Pickup address
      t.string :address, null: false
      t.string :city, null: false
      t.text :pick_up_notes

      # Coordinator-verified address (separate from customer input)
      t.string :verified_address
      t.decimal :verified_latitude, precision: 9, scale: 6
      t.decimal :verified_longitude, precision: 9, scale: 6

      # Scheduling
      t.datetime :pick_up_at
      t.datetime :delivery_at

      # Lifecycle
      t.enum :status, enum_type: :requests_status, default: "pending", null: false
      t.text :cancelled_reason
      t.datetime :cancelled_at

      # Processing — `items_only` means the order is priced per piece
      # (e.g. quilts) and no weighing step is needed.
      t.boolean :items_only, default: false, null: false
      t.integer :number_of_items
      t.decimal :weight, precision: 10, scale: 2
      t.decimal :amount, precision: 10, scale: 2

      # Voucher
      t.references :voucher, foreign_key: { on_delete: :nullify }
      t.integer :voucher_count, default: 0, null: false
      t.string :voucher_source
      t.boolean :voucher_received, default: false, null: false

      # Courier assignment (one per leg)
      t.references :pickup_courier,
                   foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :delivery_courier,
                   foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :route_position

      t.timestamps
    end

    add_index :requests, :customer_id, unique: true
    add_index :requests, :status
    add_index :requests, [:pickup_courier_id, :status]
    add_index :requests, [:delivery_courier_id, :status]

    # TZ-aware partial indexes for the courier "today" queries.
    execute <<~SQL
      CREATE INDEX index_requests_pickup_today
        ON requests (((pick_up_at AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Sofia')::date))
        WHERE status IN ('pickup_confirmed', 'picked_up');
    SQL
    execute <<~SQL
      CREATE INDEX index_requests_delivery_today
        ON requests (((delivery_at AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Sofia')::date))
        WHERE status IN ('delivery_confirmed', 'delivered');
    SQL
  end
end
