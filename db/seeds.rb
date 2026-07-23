# Idempotent. Safe to re-run.
#
# Always (any env): ensure the canonical demo factories exist with their
# first admin user.
# Development only: load demo Requests + extra role users into the default
# (Bulgarian) factory so the admin UI has shape after `bin/rails db:setup`.

ADMIN_SEED_PASSWORD = ENV.fetch("ADMIN_SEED_PASSWORD", "password").freeze

# ---------- Default (Bulgaria, bg/BGN) ----------
default_factory = Factory.find_or_create_by!(slug: "default") do |f|
  f.name                  = "Nexus Cleaning"
  f.legal_name            = "Nexus Cleaning"
  f.country_code          = "BG"
  f.timezone              = "Europe/Sofia"
  f.currency              = "BGN"
  f.default_locale        = "bg"
  f.phone_country         = "BG"
  f.phone                 = "+359 899 771 972"
  f.email                 = "office@nexus-cleaning.com"
  f.pickup_window         = "18:00 – 20:30"
  f.business_hours        = "09:00 – 20:00"
  f.price_per_kg          = 1.50
  f.price_per_kg_bulk     = 1.35
  f.bulk_weight_threshold = 50
  f.price_per_item        = 7.50
  f.same_day_cutoff_hour  = 16
  f.service_cities = %w[
    Пловдив Асеновград Брестник Брестовица Войводиново Крумово Марково
    Перущица Първенец Строево Труд Храбрино Цалапица
  ]
end

# ---------- Acme (UK, en/GBP) ----------
acme_factory = Factory.find_or_create_by!(slug: "acme") do |f|
  f.name                  = "Acme Carpet Wash"
  f.legal_name            = "Acme Carpet Wash Ltd."
  f.country_code          = "GB"
  f.timezone              = "Europe/London"
  f.currency              = "GBP"
  f.default_locale        = "en"
  f.phone_country         = "GB"
  f.phone                 = "+44 20 7946 0123"
  f.email                 = "hello@acme-carpets.test"
  f.pickup_window         = "18:00 – 21:00"
  f.business_hours        = "09:00 – 19:00"
  f.price_per_kg          = 4.50
  f.price_per_kg_bulk     = 3.95
  f.bulk_weight_threshold = 50
  f.price_per_item        = 22.00
  f.same_day_cutoff_hour  = 15
  f.service_cities        = ["Central London", "Camden", "Islington", "Hackney"]
end

# ---------- Lakeview (Germany, en/EUR) ----------
lakeview_factory = Factory.find_or_create_by!(slug: "lakeview") do |f|
  f.name                  = "Lakeview Carpets"
  f.legal_name            = "Lakeview Carpets GmbH"
  f.country_code          = "DE"
  f.timezone              = "Europe/Berlin"
  f.currency              = "EUR"
  f.default_locale        = "en"
  f.phone_country         = "DE"
  f.phone                 = "+49 30 1234 5678"
  f.email                 = "hello@lakeview.test"
  f.pickup_window         = "18:00 – 20:00"
  f.business_hours        = "09:00 – 18:00"
  f.price_per_kg          = 3.20
  f.price_per_kg_bulk     = 2.80
  f.bulk_weight_threshold = 60
  f.price_per_item        = 14.00
  f.same_day_cutoff_hour  = 14
  f.service_cities        = ["Mitte", "Kreuzberg", "Friedrichshain", "Charlottenburg"]
end

# An admin for every factory so every seeded tenant is loginable. Email is
# scoped per factory (acts_as_tenant), so we can reuse `admin@<slug>.test`
# without collisions.
[
  [default_factory,  "admin@example.com"],
  [acme_factory,     "admin@acme.test"],
  [lakeview_factory, "admin@lakeview.test"],
].each do |factory, email|
  ActsAsTenant.with_tenant(factory) do
    admin = User.find_or_initialize_by(email: email)
    if admin.new_record?
      admin.password = ADMIN_SEED_PASSWORD
      admin.role     = "admin"
      admin.save!
      puts "[seeds] #{factory.slug.ljust(10)} admin: #{email} / #{ADMIN_SEED_PASSWORD}"
    else
      puts "[seeds] #{factory.slug.ljust(10)} admin already exists: #{email}"
    end
  end
end

unless Rails.env.development?
  puts "[seeds] Skipping demo fixtures — development-only (Rails.env=#{Rails.env})."
  return
end

# ---------- Dev-only demo fixtures, default tenant only ----------
# Acme and Lakeview stay empty so it's obvious what a freshly-onboarded
# factory looks like.
ActsAsTenant.with_tenant(default_factory) do
  # FK-safe order: clear requests first, then non-admin users.
  Request.delete_all
  User.where.not(email: "admin@example.com").delete_all

  role_users = [
    { email: "courier@example.com",     role: "courier" },
    { email: "courier2@example.com",    role: "courier" },
    { email: "operator@example.com",    role: "operator" },
    { email: "coordinator@example.com", role: "coordinator" },
  ]
  role_users.each do |attrs|
    User.find_or_create_by!(email: attrs[:email]) do |u|
      u.password = "1"
      u.role     = attrs[:role]
    end
  end

  requests_data = [
    { phone: "0881234567", address: "бул. Шести септември 12", city: "Пловдив",       pick_up_at: Date.tomorrow,   status: "pending",            pick_up_notes: "Моля, обадете се преди да дойдете." },
    { phone: "0889876543", address: "ул. Иван Вазов 45",       city: "Пловдив",       pick_up_at: Date.tomorrow,   status: "pickup_confirmed" },
    { phone: "0878112233", address: "ул. Капитан Райчо 8",     city: "Асеновград",    pick_up_at: 2.days.from_now, status: "picked_up",          number_of_items: 4 },
    { phone: "0876543210", address: "ул. Шипка 14",            city: "Пловдив",       pick_up_at: 2.days.from_now, status: "picked_up",          number_of_items: 2 },
    { phone: "0887445566", address: "ул. Главна 17",           city: "Перущица",      pick_up_at: 2.days.from_now, status: "in_progress",        pick_up_notes: "Втори етаж, без асансьор.", number_of_items: 3, weight: 12.4 },
    { phone: "0899334455", address: "ул. Васил Левски 23",     city: "Крумово",       pick_up_at: 2.days.from_now, status: "ready_for_delivery", number_of_items: 5, weight: 18.7 },
    { phone: "0988778899", address: "ул. Цар Симеон 5",        city: "Цалапица",      pick_up_at: 2.days.from_now, status: "delivery_confirmed", number_of_items: 1, weight: 4.2, delivery_at: 5.days.from_now },
    { phone: "0871122334", address: "бул. България 100",       city: "Брестовица",    pick_up_at: 3.days.from_now, status: "delivered",          number_of_items: 2, weight: 9.1 },
    { phone: "0883344556", address: "ул. Граф Игнатиев 32",    city: "Брестовица",    pick_up_at: 2.days.from_now, status: "cancelled" },
    { phone: "0884556677", address: "ул. Иван Рилски 4",       city: "Перущица",      pick_up_at: Date.tomorrow,   status: "pending" },
    { phone: "0882001122", address: "ул. Дондуков 5",          city: "Пловдив",       pick_up_at: Date.tomorrow,   status: "pending" },
    { phone: "0888223344", address: "бул. Цар Борис III 88",   city: "Пловдив",       pick_up_at: Date.tomorrow,   status: "pending" },
    { phone: "0897445566", address: "ул. Любен Каравелов 9",   city: "Марково",       pick_up_at: Date.tomorrow,   status: "pickup_confirmed",   number_of_items: 2 },
    { phone: "0898001122", address: "ул. Райко Даскалов 3",    city: "Брестник",      pick_up_at: 2.days.from_now, status: "pickup_confirmed",   pick_up_notes: "След 19:00." },
    { phone: "0876778899", address: "ул. Хан Аспарух 7",       city: "Войводиново",   pick_up_at: 3.days.from_now, status: "pending" },
  ]
  created_requests = requests_data.map { |data| Request.create!(data) }

  # Spread created_at so the reports chart has shape.
  created_requests.each_with_index do |request, idx|
    backdated = (60 * idx / created_requests.size.to_f).to_i.days.ago - rand(0..18).hours
    request.update_columns(created_at: backdated, updated_at: backdated + rand(1..6).hours)
  end

  puts "[seeds] Created #{requests_data.size} demo requests in 'default'"
end

# Platform operator for the super-admin console (admin.rugsuiteerp.com).
# Dev/test only — in production create via `bin/kamal console`:
#   PlatformAdmin.create!(email: "you@example.com", password: "…")
if Rails.env.local? && PlatformAdmin.none?
  PlatformAdmin.create!(email: "platform@rugsuiteerp.com", password: "password")
  puts "[seeds] Created platform admin platform@rugsuiteerp.com / password"
end
