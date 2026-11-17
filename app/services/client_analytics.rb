# Client-level figures for the admin "Statistics" page (ported from
# nexus-cleaning). A client is a phone number, normalised to E.164 for the
# factory's country so "0888…" and "+359888…" match; an order counts on its
# pickup date in the factory's timezone. The caller decides which orders to
# include (cancelled ones are left out).
class ClientAnalytics
  FREQUENCY_BUCKETS = [ 1, 2, 3, 4, 5 ].freeze # the last one means "5 or more"

  Order = Struct.new(:client, :date, :amount, :weight, :phone, :address, keyword_init: true)
  Client = Struct.new(:key, :phone, :address, :orders, keyword_init: true) do
    def first_date = orders.first.date
    def last_date = orders.last.date
    def revenue = orders.sum { |o| o.amount.to_f }
    def weight = orders.sum { |o| o.weight.to_f }
    def repeat? = orders.size > 1
  end

  def initialize(scope, country: nil, time_zone: Time.zone)
    @country = country
    rows = scope.pluck(:phone, :pick_up_at, :created_at, :amount, :weight, :address)
    @orders = rows.filter_map do |phone, pick_up_at, created_at, amount, weight, address|
      key = client_key(phone)
      next if key.blank?

      Order.new(client: key, date: (pick_up_at || created_at).in_time_zone(time_zone).to_date,
                amount: amount, weight: weight, phone: phone, address: address)
    end.sort_by(&:date)

    @clients = @orders.group_by(&:client).map do |key, orders|
      Client.new(key: key, phone: orders.last.phone, address: orders.last.address, orders: orders)
    end
  end

  def client_key(phone)
    parsed = Phonelib.parse(phone.to_s, @country)
    parsed.valid? ? parsed.e164 : phone.to_s.gsub(/\D/, "").presence
  end

  def any? = @orders.any?

  def totals
    repeat = @clients.count(&:repeat?)
    {
      clients: @clients.size,
      orders: @orders.size,
      repeat_clients: repeat,
      repeat_share: @clients.any? ? repeat * 100.0 / @clients.size : 0,
      orders_per_client: @clients.any? ? @orders.size.to_f / @clients.size : 0,
      revenue_per_client: @clients.any? ? @clients.sum(&:revenue) / @clients.size : 0,
      days_between_orders: average_gap_days,
    }
  end

  # One row per month or year, newest first: how many clients ordered, how
  # many of them were new, how many came back from an earlier period, how
  # many ordered more than once inside it, and how many of the period's new
  # clients have ordered again since.
  def periods(grouping)
    first_period = @clients.to_h { |c| [ c.key, period_key(c.first_date, grouping) ] }

    @orders.group_by { |o| period_key(o.date, grouping) }.sort.reverse.map do |key, orders|
      by_client = orders.group_by(&:client)
      new_keys = by_client.keys.select { |k| first_period[k] == key }
      came_back = new_keys.count { |k| client(k).orders.any? { |o| period_key(o.date, grouping) > key } }
      revenue = orders.sum { |o| o.amount.to_f }

      {
        key: key,
        label: period_label(key, grouping),
        orders: orders.size,
        clients: by_client.size,
        new_clients: new_keys.size,
        returning_clients: by_client.size - new_keys.size,
        repeat_in_period: by_client.count { |_, os| os.size > 1 },
        new_came_back: came_back,
        revenue: revenue,
        weight: orders.sum { |o| o.weight.to_f },
        average_order: orders.any? ? revenue / orders.size : 0,
      }
    end
  end

  # How many clients ordered once, twice, … five or more times.
  def frequency
    counts = @clients.map { |c| [ c.orders.size, FREQUENCY_BUCKETS.last ].min }.tally
    FREQUENCY_BUCKETS.map { |n| [ n, counts[n].to_i ] }
  end

  def top_clients(limit = 10)
    @clients.sort_by { |c| [ -c.revenue, -c.orders.size ] }.first(limit)
  end

  private

  def client(key)
    @clients_by_key ||= @clients.index_by(&:key)
    @clients_by_key[key]
  end

  def average_gap_days
    gaps = @clients.select(&:repeat?).flat_map do |c|
      c.orders.map(&:date).uniq.each_cons(2).map { |a, b| (b - a).to_i }
    end
    gaps.any? ? gaps.sum.to_f / gaps.size : nil
  end

  def period_key(date, grouping)
    grouping == :year ? date.year.to_s : date.strftime("%Y-%m")
  end

  def period_label(key, grouping)
    return key if grouping == :year

    year, month = key.split("-").map(&:to_i)
    "#{I18n.t('date.standalone_month_names', default: I18n.t('date.month_names'))[month]&.capitalize} #{year}"
  end
end
