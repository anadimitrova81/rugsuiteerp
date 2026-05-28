# Idempotent. Safe to re-run.
#
# Always: ensure the bootstrap Factory exists (any environment).
# Development only: load a pile of demo Requests so the app has shape after
# `bin/rails db:setup`.

default_factory = Factory.find_or_create_by!(slug: "default") do |f|
  f.name = "Nexus Cleaning"
  f.legal_name           = "Nexus Cleaning"
  f.country_code         = "BG"
  f.timezone             = "Europe/Sofia"
  f.currency             = "BGN"
  f.default_locale       = "bg"
  f.phone_country        = "BG"
  f.phone                = "+359 899 771 972"
  f.email                = "office@nexus-cleaning.com"
  f.hero_tagline         = nil
  f.pickup_window        = "18:00 – 20:30"
  f.business_hours       = "09:00 – 20:00"
  f.price_per_kg         = 1.50
  f.price_per_kg_bulk    = 1.35
  f.bulk_weight_threshold = 50
  f.price_per_item       = 7.50
  f.same_day_cutoff_hour = 16
  f.service_cities = [
    "Пловдив", "Асеновград", "Брани поле", "Брестник", "Брестовица",
    "Войводиново", "Злати трап", "Йоаким Груево", "Крумово", "Марково",
    "Перущица", "Първенец", "Строево", "Труд", "Храбрино", "Цалапица",
  ]
end
puts "[seeds] Factory: #{default_factory.slug} (id=#{default_factory.id})"

# All tenant-scoped writes from here on must run inside with_tenant.
ActsAsTenant.with_tenant(default_factory) do
  # A reliable admin login that exists in every environment so a freshly
  # provisioned tenant is never locked out. Override the password in
  # production via the ADMIN_SEED_PASSWORD env var.
  admin = User.find_or_initialize_by(email: "admin@example.com")
  if admin.new_record?
    admin.password = ENV.fetch("ADMIN_SEED_PASSWORD", "password")
    admin.role = "admin"
    admin.save!
    puts "[seeds] Admin user: admin@example.com (password from ADMIN_SEED_PASSWORD or 'password')"
  end
end

unless Rails.env.development?
  puts "[seeds] Skipping demo fixtures — development-only (Rails.env=#{Rails.env})."
  return
end

# ---------- Dev-only demo fixtures (inside the default tenant) ----------

ActsAsTenant.with_tenant(default_factory) do
  # Clear in FK-safe order so re-running the seed never trips on the
  # requests.pickup_courier_id / delivery_courier_id constraints. These deletes
  # are tenant-scoped because of acts_as_tenant — other factories untouched.
  Request.delete_all
  User.where.not(email: "admin@example.com").delete_all

  users = [
    { email: "courier@example.com",     role: "courier" },
    { email: "courier2@example.com",    role: "courier" },
    { email: "operator@example.com",    role: "operator" },
    { email: "coordinator@example.com", role: "coordinator" },
  ]

  users.each do |attrs|
    user = User.find_or_create_by(email: attrs[:email]) do |u|
      u.password = "1"
      u.role = attrs[:role]
    end
    puts "Потребител: #{user.email} / парола: 1 (#{User::ROLE_LABELS[attrs[:role]]})"
  end

  requests_data = [
    { phone: "0881234567", address: "бул. Шести септември 12",        city: "Пловдив",        pick_up_at: Date.tomorrow,    status: "pending",            pick_up_notes: "Моля, обадете се преди да дойдете." },
    { phone: "0889876543", address: "ул. Иван Вазов 45",              city: "Пловдив",        pick_up_at: Date.tomorrow,    status: "pickup_confirmed" },
    { phone: "0878112233", address: "ул. Капитан Райчо 8",            city: "Асеновград",     pick_up_at: 2.days.from_now,  status: "picked_up",          number_of_items: 4 },
    { phone: "0876543210", address: "ул. Шипка 14",                   city: "Пловдив",        pick_up_at: 2.days.from_now,  status: "picked_up",          number_of_items: 2 },
    { phone: "0887445566", address: "ул. Главна 17",                  city: "Перущица",       pick_up_at: 2.days.from_now,  status: "in_progress",        pick_up_notes: "Втори етаж, без асансьор.", number_of_items: 3, weight: 12.4 },
    { phone: "0899334455", address: "ул. Васил Левски 23",            city: "Крумово",        pick_up_at: 2.days.from_now,  status: "ready_for_delivery", number_of_items: 5, weight: 18.7 },
    { phone: "0988778899", address: "ул. Цар Симеон 5",               city: "Цалапица",       pick_up_at: 2.days.from_now,  status: "delivery_confirmed", number_of_items: 1, weight: 4.2, delivery_at: 5.days.from_now },
    { phone: "0871122334", address: "бул. България 100",              city: "Брестовица",     pick_up_at: 3.days.from_now,  status: "delivered",          number_of_items: 2, weight: 9.1 },
    { phone: "0883344556", address: "ул. Граф Игнатиев 32",           city: "Злати трап",     pick_up_at: 2.days.from_now,  status: "cancelled" },
    { phone: "0884556677", address: "ул. Иван Рилски 4",              city: "Йоаким Груево",  pick_up_at: Date.tomorrow,    status: "pending",            pick_up_notes: "Звънете на звънеца два пъти." },
    { phone: "0882001122", address: "ул. Дондуков 5",                 city: "Пловдив",        pick_up_at: Date.tomorrow,    status: "pending" },
    { phone: "0888223344", address: "бул. Цар Борис III 88",          city: "Пловдив",        pick_up_at: Date.tomorrow,    status: "pending",            pick_up_notes: "Партер, домофон 12." },
    { phone: "0897445566", address: "ул. Любен Каравелов 9",          city: "Марково",        pick_up_at: Date.tomorrow,    status: "pickup_confirmed",   number_of_items: 2 },
    { phone: "0898001122", address: "ул. Райко Даскалов 3",           city: "Брестник",       pick_up_at: 2.days.from_now,  status: "pickup_confirmed",   pick_up_notes: "След 19:00." },
    { phone: "0876778899", address: "ул. Хан Аспарух 7",              city: "Войводиново",    pick_up_at: 3.days.from_now,  status: "pending" },
  ]

  created_requests = requests_data.map { |data| Request.create!(data) }

  # Spread created_at so the reports chart has shape.
  created_requests.each_with_index do |request, idx|
    backdated = (60 * idx / created_requests.size.to_f).to_i.days.ago - rand(0..18).hours
    request.update_columns(created_at: backdated, updated_at: backdated + rand(1..6).hours)
  end

  puts "[seeds] Created #{requests_data.size} demo requests"
end
