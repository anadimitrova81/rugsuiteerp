# Idempotent. Safe to re-run.
#
# Always (any env): ensure the canonical demo factories exist with their
# first admin user.
# Development only: load demo Requests + extra role users into the demo
# (Bulgarian) factory so the admin UI has shape after `bin/rails db:setup`.

ADMIN_SEED_PASSWORD = ENV.fetch("ADMIN_SEED_PASSWORD", "password").freeze

# ---------- Demo (Bulgaria, bg/BGN) — the public live demo ----------
demo_factory = Factory.find_or_create_by!(slug: DemoCompanySeeder::SLUG) do |f|
  f.name                  = "Demo Rug Wash"
  f.legal_name            = "Demo Rug Wash"
  f.country_code          = "BG"
  f.timezone              = "Europe/Sofia"
  f.currency              = "BGN"
  f.default_locale        = "bg"
  f.phone_country         = "BG"
  f.phone                 = "+359 899 771 972"
  f.email                 = "office@example.com"
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
  [demo_factory,     "admin@example.com"],
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

# ---------- Dev-only demo fixtures, demo tenant only ----------
# Acme and Lakeview stay empty so it's obvious what a freshly-onboarded
# factory looks like. Same seeder the daily job and the platform console use,
# so dev matches production (staff password: DemoCompanySeeder::DEMO_STAFF_PASSWORD).
count = DemoCompanySeeder.reseed!
puts "[seeds] Created #{count} demo requests in '#{DemoCompanySeeder::SLUG}'"

# Platform operator for the super-admin console (admin.rugsuiteerp.com).
# Dev/test only — in production create via `bin/kamal console`:
#   PlatformAdmin.create!(email: "you@example.com", password: "…")
if Rails.env.local? && PlatformAdmin.none?
  PlatformAdmin.create!(email: "platform@rugsuiteerp.com", password: "password")
  puts "[seeds] Created platform admin platform@rugsuiteerp.com / password"
end
