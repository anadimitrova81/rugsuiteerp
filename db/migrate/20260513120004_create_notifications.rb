class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :request, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :channel, default: "sms", null: false
      t.string :recipient, null: false
      t.text :body, null: false
      t.string :provider_message_id
      t.string :status, default: "sent", null: false
      t.text :error_message
      t.datetime :sent_at, null: false
      t.timestamps
    end
    add_index :notifications, [:request_id, :kind]
    add_index :notifications, :sent_at
  end
end
