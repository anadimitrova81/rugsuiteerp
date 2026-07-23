class CreatePlatformAdmins < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_admins do |t|
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :platform_admins, :email, unique: true
  end
end
