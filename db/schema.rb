# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_09_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "requests_status", ["pending", "pickup_confirmed", "picked_up", "in_progress", "ready_for_delivery", "delivery_confirmed", "delivered", "cancelled"]
  create_enum "user_role", ["admin", "courier", "operator", "coordinator"]

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "factories", force: :cascade do |t|
    t.string "brand_primary_color"
    t.string "brand_secondary_color"
    t.decimal "bulk_area_threshold", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "bulk_weight_threshold", precision: 10, scale: 2, default: "0.0", null: false
    t.string "business_hours"
    t.string "country_code", limit: 2, null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.string "default_locale", limit: 8, default: "en", null: false
    t.string "email"
    t.string "hero_tagline"
    t.string "legal_name"
    t.string "name", null: false
    t.string "phone"
    t.string "phone_country", limit: 2, null: false
    t.string "pickup_window"
    t.string "plan", default: "trial", null: false
    t.decimal "price_per_item", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "price_per_kg", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "price_per_kg_bulk", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "price_per_sqm", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "price_per_sqm_bulk", precision: 10, scale: 2, default: "0.0", null: false
    t.string "pricing_mode", default: "per_kg", null: false
    t.integer "same_day_cutoff_hour", default: 16, null: false
    t.jsonb "service_cities", default: [], null: false
    t.string "slug", null: false
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["plan"], name: "index_factories_on_plan"
    t.index ["slug"], name: "index_factories_on_slug", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body", null: false
    t.string "channel", default: "sms", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "factory_id", null: false
    t.string "kind", null: false
    t.string "provider_message_id"
    t.string "recipient", null: false
    t.bigint "request_id", null: false
    t.datetime "sent_at", null: false
    t.string "status", default: "sent", null: false
    t.datetime "updated_at", null: false
    t.index ["factory_id"], name: "index_notifications_on_factory_id"
    t.index ["request_id", "kind"], name: "index_notifications_on_request_id_and_kind"
    t.index ["request_id"], name: "index_notifications_on_request_id"
    t.index ["sent_at"], name: "index_notifications_on_sent_at"
  end

  create_table "page_visits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "factory_id", null: false
    t.string "path"
    t.string "referrer"
    t.string "route_key", null: false
    t.string "user_agent"
    t.index ["created_at"], name: "index_page_visits_on_created_at"
    t.index ["factory_id"], name: "index_page_visits_on_factory_id"
    t.index ["route_key"], name: "index_page_visits_on_route_key"
  end

  create_table "requests", force: :cascade do |t|
    t.string "address", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.boolean "bulk_price", default: false, null: false
    t.datetime "cancelled_at"
    t.text "cancelled_reason"
    t.string "city", null: false
    t.datetime "created_at", null: false
    t.string "customer_id"
    t.datetime "delivery_at"
    t.bigint "delivery_courier_id"
    t.text "delivery_notes"
    t.bigint "factory_id", null: false
    t.boolean "items_only", default: false, null: false
    t.integer "number_of_items"
    t.boolean "paid_by_card", default: false, null: false
    t.string "phone", null: false
    t.datetime "pick_up_at"
    t.text "pick_up_notes"
    t.bigint "pickup_courier_id"
    t.integer "route_position"
    t.enum "status", default: "pending", null: false, enum_type: "requests_status"
    t.string "status_token", null: false
    t.datetime "updated_at", null: false
    t.string "verified_address"
    t.decimal "verified_latitude", precision: 9, scale: 6
    t.decimal "verified_longitude", precision: 9, scale: 6
    t.boolean "voucher", default: false, null: false
    t.decimal "weight", precision: 10, scale: 2
    t.index "((((delivery_at AT TIME ZONE 'UTC'::text) AT TIME ZONE 'Europe/Sofia'::text))::date)", name: "index_requests_delivery_today", where: "(status = ANY (ARRAY['delivery_confirmed'::requests_status, 'delivered'::requests_status]))"
    t.index "((((pick_up_at AT TIME ZONE 'UTC'::text) AT TIME ZONE 'Europe/Sofia'::text))::date)", name: "index_requests_pickup_today", where: "(status = ANY (ARRAY['pickup_confirmed'::requests_status, 'picked_up'::requests_status]))"
    t.index ["delivery_courier_id", "status"], name: "index_requests_on_delivery_courier_id_and_status"
    t.index ["delivery_courier_id"], name: "index_requests_on_delivery_courier_id"
    t.index ["factory_id", "customer_id"], name: "index_requests_on_factory_id_and_customer_id", unique: true, where: "(customer_id IS NOT NULL)"
    t.index ["factory_id"], name: "index_requests_on_factory_id"
    t.index ["pickup_courier_id", "status"], name: "index_requests_on_pickup_courier_id_and_status"
    t.index ["pickup_courier_id"], name: "index_requests_on_pickup_courier_id"
    t.index ["status"], name: "index_requests_on_status"
    t.index ["status_token"], name: "index_requests_on_status_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "factory_id", null: false
    t.string "password_digest", null: false
    t.enum "role", default: "operator", null: false, enum_type: "user_role"
    t.datetime "updated_at", null: false
    t.index ["factory_id", "email"], name: "index_users_on_factory_id_and_email", unique: true
    t.index ["factory_id"], name: "index_users_on_factory_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "notifications", "factories"
  add_foreign_key "notifications", "requests", on_delete: :cascade
  add_foreign_key "page_visits", "factories"
  add_foreign_key "requests", "factories"
  add_foreign_key "requests", "users", column: "delivery_courier_id", on_delete: :nullify
  add_foreign_key "requests", "users", column: "pickup_courier_id", on_delete: :nullify
  add_foreign_key "users", "factories"
end
