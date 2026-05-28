class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_enum :user_role, %w[admin courier operator coordinator]

    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.enum :role, enum_type: :user_role, default: "operator", null: false
      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
