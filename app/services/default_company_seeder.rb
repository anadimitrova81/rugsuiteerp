# Fresh demo data for the "default" company — used for live demos. Wipes and
# recreates that company's orders (never touches any other tenant) and ensures a
# set of demo staff exist. Safe to run repeatedly; each run re-anchors the dates
# to "now" so orders always look current.
class DefaultCompanySeeder
  SLUG = "default".freeze
  DEMO_STAFF_PASSWORD = "demo1234".freeze

  STAFF = [
    { email: "courier@example.com",     role: "courier" },
    { email: "courier2@example.com",    role: "courier" },
    { email: "operator@example.com",    role: "operator" },
    { email: "coordinator@example.com", role: "coordinator" },
  ].freeze

  # pick_up_at is filled in relative to today at run time (see #requests_data).
  def self.reseed!
    factory = Factory.find_by(slug: SLUG)
    raise "No '#{SLUG}' company found" unless factory

    ActsAsTenant.with_tenant(factory) do
      ensure_staff
      Request.delete_all
      created = requests_data.map { |attrs| Request.create!(attrs) }
      backdate(created)
      created.size
    end
  end

  def self.ensure_staff
    STAFF.each do |attrs|
      user = User.find_or_initialize_by(email: attrs[:email])
      next unless user.new_record?

      user.role = attrs[:role]
      user.password = DEMO_STAFF_PASSWORD
      user.save!
    end
  end

  # Spread created_at over ~2 months so the reports chart has shape.
  def self.backdate(requests)
    requests.each_with_index do |request, idx|
      backdated = (60 * idx / requests.size.to_f).to_i.days.ago - rand(0..18).hours
      request.update_columns(created_at: backdated, updated_at: backdated + rand(1..6).hours)
    end
  end

  # The n-th business day from today (weekends skipped) — pickups can't fall on
  # a weekend, and "tomorrow" may be a Saturday depending on the run day.
  def self.business_day(n)
    date = Date.current
    remaining = n
    while remaining.positive?
      date += 1
      remaining -= 1 unless date.saturday? || date.sunday?
    end
    date
  end

  def self.requests_data
    d1 = business_day(1)
    d2 = business_day(2)
    d3 = business_day(3)
    d5 = business_day(5)
    [
      { phone: "0881234567", address: "бул. Шести септември 12", city: "Пловдив",    pick_up_at: d1, status: "pending",            pick_up_notes: "Моля, обадете се преди да дойдете." },
      { phone: "0889876543", address: "ул. Иван Вазов 45",       city: "Пловдив",    pick_up_at: d1, status: "pickup_confirmed" },
      { phone: "0878112233", address: "ул. Капитан Райчо 8",     city: "Асеновград", pick_up_at: d2, status: "picked_up",          number_of_items: 4 },
      { phone: "0876543210", address: "ул. Шипка 14",            city: "Пловдив",    pick_up_at: d2, status: "picked_up",          number_of_items: 2 },
      { phone: "0887445566", address: "ул. Главна 17",           city: "Перущица",   pick_up_at: d2, status: "in_progress",        pick_up_notes: "Втори етаж, без асансьор.", number_of_items: 3, weight: 12.4 },
      { phone: "0899334455", address: "ул. Васил Левски 23",     city: "Крумово",    pick_up_at: d2, status: "ready_for_delivery", number_of_items: 5, weight: 18.7 },
      { phone: "0988778899", address: "ул. Цар Симеон 5",        city: "Цалапица",   pick_up_at: d2, status: "delivery_confirmed", number_of_items: 1, weight: 4.2, delivery_at: d5 },
      { phone: "0871122334", address: "бул. България 100",       city: "Брестовица", pick_up_at: d3, status: "delivered",          number_of_items: 2, weight: 9.1 },
      { phone: "0883344556", address: "ул. Граф Игнатиев 32",    city: "Брестовица", pick_up_at: d2, status: "cancelled" },
      { phone: "0884556677", address: "ул. Иван Рилски 4",       city: "Перущица",   pick_up_at: d1, status: "pending" },
      { phone: "0882001122", address: "ул. Дондуков 5",          city: "Пловдив",    pick_up_at: d1, status: "pending" },
      { phone: "0888223344", address: "бул. Цар Борис III 88",   city: "Пловдив",    pick_up_at: d1, status: "pending" },
      { phone: "0897445566", address: "ул. Любен Каравелов 9",   city: "Марково",    pick_up_at: d1, status: "pickup_confirmed",   number_of_items: 2 },
      { phone: "0898001122", address: "ул. Райко Даскалов 3",    city: "Брестник",   pick_up_at: d2, status: "pickup_confirmed",   pick_up_notes: "След 19:00." },
      { phone: "0876778899", address: "ул. Хан Аспарух 7",       city: "Войводиново", pick_up_at: d3, status: "pending" },
    ]
  end
end
