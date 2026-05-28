class AddFactoryRefsToExistingModels < ActiveRecord::Migration[8.1]
  # Adds factory_id to every tenant-owned table, backfills any existing rows
  # to a single seeded factory, then enforces NOT NULL + FK.
  def up
    add_reference :users,         :factory, foreign_key: true
    add_reference :requests,      :factory, foreign_key: true
    add_reference :notifications, :factory, foreign_key: true
    add_reference :page_visits,   :factory, foreign_key: true

    default_factory_id = ensure_default_factory!

    say_with_time "Backfilling factory_id on existing rows" do
      execute "UPDATE users         SET factory_id = #{default_factory_id} WHERE factory_id IS NULL"
      execute "UPDATE requests      SET factory_id = #{default_factory_id} WHERE factory_id IS NULL"
      execute "UPDATE notifications SET factory_id = #{default_factory_id} WHERE factory_id IS NULL"
      execute "UPDATE page_visits   SET factory_id = #{default_factory_id} WHERE factory_id IS NULL"
    end

    change_column_null :users,         :factory_id, false
    change_column_null :requests,      :factory_id, false
    change_column_null :notifications, :factory_id, false
    change_column_null :page_visits,   :factory_id, false

    # User email must now be unique per-factory, not globally.
    remove_index :users, :email
    add_index :users, [:factory_id, :email], unique: true

    # Request customer_id must now be unique per-factory.
    remove_index :requests, :customer_id
    add_index :requests, [:factory_id, :customer_id], unique: true, where: "customer_id IS NOT NULL"

    # Request status_token is a public-facing token; keep globally unique.
    # (Already indexed unique in CreateRequests.)
  end

  def down
    remove_index :requests, [:factory_id, :customer_id]
    add_index :requests, :customer_id, unique: true

    remove_index :users, [:factory_id, :email]
    add_index :users, :email, unique: true

    remove_reference :page_visits,   :factory, foreign_key: true
    remove_reference :notifications, :factory, foreign_key: true
    remove_reference :requests,      :factory, foreign_key: true
    remove_reference :users,         :factory, foreign_key: true
  end

  private

  # Seed a single Bulgarian-origin factory carrying the values that used to be
  # hardcoded in the app. Existing dev/staging data (if any) backfills into it.
  def ensure_default_factory!
    existing = select_value("SELECT id FROM factories ORDER BY id LIMIT 1")
    return existing.to_i if existing

    cities_json = ActiveRecord::Base.connection.quote([
      "Пловдив", "Асеновград", "Брани поле", "Брестник", "Брестовица",
      "Войводиново", "Злати трап", "Йоаким Груево", "Крумово", "Марково",
      "Перущица", "Първенец", "Строево", "Труд", "Храбрино", "Цалапица"
    ].to_json)

    execute <<~SQL
      INSERT INTO factories (
        slug, name, country_code, timezone, currency, default_locale, phone_country,
        price_per_kg, price_per_kg_bulk, bulk_weight_threshold, price_per_item,
        same_day_cutoff_hour, service_cities, created_at, updated_at
      ) VALUES (
        'default', 'Default Factory', 'BG', 'Europe/Sofia', 'BGN', 'bg', 'BG',
        1.50, 1.35, 50, 7.50,
        16, #{cities_json}::jsonb, NOW(), NOW()
      )
    SQL

    select_value("SELECT id FROM factories WHERE slug = 'default'").to_i
  end
end
