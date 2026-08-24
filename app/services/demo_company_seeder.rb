# Fresh demo data for the public "demo" company (demo.<domain>, advertised on
# the marketing site). Wipes and recreates that company's orders (never touches
# any other tenant) and ensures a set of demo staff exist. Safe to run
# repeatedly; each run re-anchors the dates to "now" so orders always look
# current. Run daily via config/recurring.yml and on demand from the platform
# console.
class DemoCompanySeeder
  SLUG = "demo".freeze
  DEMO_STAFF_PASSWORD = "demo1234".freeze
  # The account the marketing site's one-click demo login signs in as.
  DEMO_ADMIN_EMAIL = "admin@example.com".freeze

  STAFF = [
    { email: DEMO_ADMIN_EMAIL,          role: "admin" },
    { email: "courier@example.com",     role: "courier" },
    { email: "courier2@example.com",    role: "courier" },
    { email: "operator@example.com",    role: "operator" },
    { email: "coordinator@example.com", role: "coordinator" },
  ].freeze

  # The washing-process steps shown on the public page and editable in the
  # admin settings. In Bulgarian — the demo company's locale.
  PROCESS_STEPS = [
    { position: 1, title: "Приемане и оглед",       body: "Преглеждаме всеки килим за петна, увреждания и тип материя, и записваме размерите му." },
    { position: 2, title: "Обезпрашаване",           body: "Машинно избиване на дълбоко набития прах преди мокрото пране." },
    { position: 3, title: "Основно пране",           body: "Пране с професионални препарати, съобразени с материята и цветовете на килима." },
    { position: 4, title: "Изплакване и центрофуга", body: "Обилно изплакване с чиста вода и центрофугиране за отстраняване на влагата." },
    { position: 5, title: "Сушене",                  body: "Сушене в специализирано помещение с контролирана температура и влажност." },
    { position: 6, title: "Финален контрол",         body: "Оглед на качеството, ароматизиране и опаковане, готово за доставка." },
  ].freeze

  # pick_up_at is filled in relative to today at run time (see #requests_data).
  def self.reseed!
    factory = Factory.find_by(slug: SLUG)
    raise "No '#{SLUG}' company found" unless factory

    ActsAsTenant.with_tenant(factory) do
      ensure_staff
      reset_process_steps
      # FK-safe order: notifications reference requests.
      Notification.delete_all
      Request.delete_all
      couriers = User.where(role: "courier").order(:id).pluck(:id)
      created = requests_data.map { |attrs| Request.create!(attrs.merge(admin_initiated: true)) }
      backdate(created)
      # Today's route stops keep a fresh created_at — they were "booked recently".
      stops = route_stops_data(couriers).map { |attrs| Request.create!(attrs.merge(admin_initiated: true)) }
      seed_sent_price_quote
      created.size + stops.size
    end
  end

  # Resets role and password every run — the admin login is advertised on the
  # marketing page, so a visitor changing it must not break the demo.
  def self.ensure_staff
    STAFF.each do |attrs|
      user = User.find_or_initialize_by(email: attrs[:email])
      user.role = attrs[:role]
      user.password = DEMO_STAFF_PASSWORD
      user.save!
    end
  end

  # Today's route: confirmed pickups and deliveries dated today and assigned
  # to the two demo couriers (plus one unassigned stop, so the "unassigned"
  # lane has something in it) — the admin Routes page is empty without them.
  def self.route_stops_data(courier_ids)
    c1, c2 = courier_ids
    today = Date.current
    [
      { phone: "0888101010", address: "ул. Отец Паисий 24",   city: "Пловдив",    pick_up_at: today, status: "pickup_confirmed",   pickup_courier_id: c1 },
      { phone: "0888202020", address: "бул. Марица 128",      city: "Пловдив",    pick_up_at: today, status: "pickup_confirmed",   pickup_courier_id: c1, pick_up_notes: "Позвънете на входа." },
      { phone: "0888303030", address: "ул. Богомил 53",       city: "Пловдив",    pick_up_at: today, status: "pickup_confirmed",   pickup_courier_id: c2 },
      { phone: "0888404040", address: "ул. Съединение 11",    city: "Асеновград", pick_up_at: today, status: "pickup_confirmed",   pickup_courier_id: c2, number_of_items: 2 },
      { phone: "0888505050", address: "ул. Брезовска 42",     city: "Пловдив",    pick_up_at: today, status: "delivery_confirmed", delivery_courier_id: c1, delivery_at: today, number_of_items: 3, weight: 11.2 },
      { phone: "0888606060", address: "бул. Христо Ботев 92", city: "Пловдив",    pick_up_at: today, status: "delivery_confirmed", delivery_courier_id: c2, delivery_at: today, number_of_items: 1, weight: 5.6 },
      { phone: "0888707070", address: "ул. Лале 9",           city: "Труд",       pick_up_at: today, status: "pickup_confirmed" },
    ]
  end

  # One in-progress order gets its price-quote SMS recorded as already "sent",
  # so the SMS log page has a realistic entry. The other in-progress order
  # stays awaiting, keeping the send-quotes button meaningful. (In the demo
  # tenant Sms::Sender only logs, so pressing it never texts anyone.)
  def self.seed_sent_price_quote
    request = Request.where(status: "in_progress").where.not(weight: nil).order(:id).first
    return unless request

    request.notifications.create!(
      kind: "price_quote", channel: "sms", recipient: request.phone,
      body: Sms::PriceQuoteMessage.build(request), status: "sent",
      sent_at: request.updated_at,
    )
  end

  # Recreated (not just topped up) so visitor edits don't outlive the reseed.
  def self.reset_process_steps
    ProcessStep.delete_all
    PROCESS_STEPS.each { |attrs| ProcessStep.create!(attrs) }
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
      { phone: "0894556677", address: "ул. Родопи 21",           city: "Пловдив",    pick_up_at: d2, status: "in_progress",        number_of_items: 2, weight: 8.3 },
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
