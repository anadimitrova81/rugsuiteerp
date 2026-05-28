class CreatePageVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :page_visits do |t|
      t.string :route_key, null: false
      t.string :path
      t.string :referrer
      t.string :user_agent
      t.datetime :created_at, null: false
    end
    add_index :page_visits, :route_key
    add_index :page_visits, :created_at
  end
end
