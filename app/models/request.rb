class Request < ApplicationRecord
  acts_as_tenant :factory

  HUMAN_ATTRIBUTE_NAMES = {
    number_of_items: "Брой артикули",
    weight: "Тегло",
    pick_up_at: "Дата на вземане",
    items_only: "Само артикули",
  }.freeze

  def self.human_attribute_name(attr, options = {})
    HUMAN_ATTRIBUTE_NAMES[attr.to_sym] || super
  end

  belongs_to :pickup_courier, class_name: "User", optional: true
  belongs_to :delivery_courier, class_name: "User", optional: true
  has_many :notifications, dependent: :destroy

  # Set by the admin controllers so staff can schedule weekend pickups. Client
  # submissions leave it false, so the weekend validation below applies to them.
  attr_accessor :admin_initiated

  # The courier responsible for this stop given its current leg.
  def current_courier_id
    if status.in?(%w[pickup_confirmed picked_up])
      pickup_courier_id
    elsif status.in?(%w[delivery_confirmed delivered])
      delivery_courier_id
    end
  end

  before_create :generate_customer_id
  before_save :regenerate_customer_id_on_pick_up_change,
              if: -> { !new_record? && pick_up_at.present? &&
                       will_save_change_to_pick_up_at? }
  before_create :generate_status_token
  before_save :clear_weight_when_items_only
  before_save :recalculate_amount,
              if: -> { will_save_change_to_weight? ||
                       will_save_change_to_number_of_items? ||
                       will_save_change_to_voucher? ||
                       will_save_change_to_bulk_price? }

  STATUSES = %w[pending pickup_confirmed picked_up in_progress ready_for_delivery delivery_confirmed delivered cancelled]

  # Translated label via I18n. Replaces the legacy STATUS_LABELS hash.
  def self.status_label(status)
    I18n.t("admin.request_status.#{status}")
  end

  def self.status_labels
    STATUSES.index_with { |s| status_label(s) }
  end
  # Currency conversion (BGN → EUR) is independent of multi-tenancy and is
  # only used for display in Bulgarian-currency factories. Will be replaced by
  # a proper currency module when more currencies are onboarded.
  BGN_PER_EUR = 1.95583

  # Per-tenant settings (cities, prices, phone validation, cutoff hour, timezone)
  # are read from the current Factory. These wrappers exist so callers don't
  # have to repeat the ActsAsTenant lookup; they raise if no tenant is set.
  class << self
    def current_factory
      ActsAsTenant.current_tenant or raise ActsAsTenant::Errors::NoTenantSet
    end

    def service_cities    = current_factory.service_cities
    def price_per_kg      = current_factory.price_per_kg
    def price_per_kg_bulk = current_factory.price_per_kg_bulk
    def price_per_item    = current_factory.price_per_item
    def bulk_weight_threshold = current_factory.bulk_weight_threshold
    def same_day_cutoff_hour  = current_factory.same_day_cutoff_hour

    # Whitelisted timezone string safe to embed in raw SQL `AT TIME ZONE 'X'`
    # fragments. IANA TZs only contain [A-Za-z0-9_+/-]; we re-check just in
    # case bad data ever lands in `factories.timezone`.
    TZ_NAME_REGEX = /\A[A-Za-z0-9_+\-\/]+\z/
    def factory_tz_sql
      tz = current_factory.timezone
      raise "Invalid factory timezone: #{tz.inspect}" unless tz.match?(TZ_NAME_REGEX)
      tz
    end
  end

  # Tab definitions for each role's index page. Labels are read from I18n
  # under admin.request_tabs.<role>.<tab_key>; the model just declares which
  # statuses belong to which tab.
  COURIER_TABS = {
    "today" =>     { statuses: %w[pickup_confirmed delivery_confirmed] },
    "completed" => { statuses: %w[picked_up delivered] },
  }.freeze

  OPERATOR_TABS = {
    "received" => { statuses: %w[picked_up] },
    "in_wash" =>  { statuses: %w[in_progress] },
    "ready" =>    { statuses: %w[ready_for_delivery] },
  }.freeze

  COORDINATOR_TABS = {
    "new" =>         { statuses: %w[pending] },
    "to_deliver" =>  { statuses: %w[ready_for_delivery] },
    "scheduled" =>   { statuses: %w[pickup_confirmed delivery_confirmed] },
  }.freeze

  validates :phone, :address, :city, :pick_up_at, presence: true
  validates :customer_id, uniqueness: { scope: :factory_id }, allow_nil: true
  validate :phone_must_be_valid_for_factory_country
  validates :number_of_items,
            presence: { message: -> (*) { I18n.t("admin.request.validations.items_required") } },
            if: -> { will_save_change_to_status? && status == "picked_up" }
  validates :number_of_items,
            numericality: { only_integer: true, greater_than: 0, message: -> (*) { I18n.t("admin.request.validations.items_positive") } },
            if: -> { will_save_change_to_status? && status == "picked_up" && number_of_items.present? }

  validates :weight,
            presence: { message: -> (*) { I18n.t("admin.request.validations.weight_required") } },
            if: -> { will_save_change_to_status? && status == "in_progress" && !items_only }
  validates :weight,
            numericality: { greater_than: 0, message: -> (*) { I18n.t("admin.request.validations.weight_positive") } },
            if: -> { will_save_change_to_status? && status == "in_progress" && weight.present? }

  validates :delivery_at,
            presence: { message: -> (*) { I18n.t("admin.request.validations.delivery_at_required") } },
            if: -> { will_save_change_to_status? && status == "delivery_confirmed" }

  # Only enforce the "not in the past" rule while the order is still
  # awaiting pickup. Once it's picked_up/in_progress/delivered, edits to
  # any other field shouldn't fail because the original pickup date has
  # since rolled into the past.
  validate :pick_up_at_not_in_the_past,
           if: -> { pick_up_at.present? &&
                    status.in?(%w[pending pickup_confirmed]) &&
                    (new_record? || will_save_change_to_pick_up_at?) }

  # Clients can only book weekday pickups; admins may schedule any day.
  validate :pick_up_at_not_on_weekend,
           if: -> { pick_up_at.present? && !admin_initiated &&
                    status.in?(%w[pending pickup_confirmed]) &&
                    (new_record? || will_save_change_to_pick_up_at?) }

  validate :address_resolvable_by_google,
           if: -> { address.present? && city.present? && (will_save_change_to_address? || will_save_change_to_city?) }

  scope :awaiting_price_notification,
        -> { where(status: "in_progress", voucher: false)
             .where("weight IS NOT NULL OR items_only = TRUE")
             .where.not(id: Notification.where(kind: "price_quote", status: "sent").select(:request_id)) }

  class << self
    def earliest_pick_up_date
      current_factory.earliest_pick_up_date
    end

    def statuses_for(role)
      {
        admin: STATUSES,
        courier: %w[pickup_confirmed delivery_confirmed picked_up delivered],
        operator: %w[picked_up in_progress ready_for_delivery],
        coordinator: %w[pending pickup_confirmed ready_for_delivery delivery_confirmed],
      }[role.to_sym]
    end

    def operator_scope(tab)
      config = OPERATOR_TABS[tab]
      return none unless config
      where(status: config[:statuses])
    end

    def coordinator_scope(tab)
      config = COORDINATOR_TABS[tab]
      return none unless config
      where(status: config[:statuses])
    end

    def courier_today_scope(tab)
      tz = factory_tz_sql
      today = Date.current
      case tab
      when "today"
        where(
          "(status = 'pickup_confirmed' AND (pick_up_at AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date = :today) " \
          "OR (status = 'delivery_confirmed' AND (delivery_at AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date = :today)",
          today: today,
        )
      when "completed"
        where(
          "(status = 'picked_up' AND (pick_up_at AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date = :today) " \
          "OR (status = 'delivered' AND (delivery_at AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date = :today)",
          today: today,
        )
      else
        none
      end
    end
  end

  def calculated_amount
    return 0 if voucher
    if weight.present?
      (weight * effective_kg_rate).round(2)
    elsif items_only && number_of_items.present?
      (number_of_items * factory.price_per_item).round(2)
    end
  end

  def effective_kg_rate
    return factory.price_per_kg_bulk if bulk_price
    return factory.price_per_kg_bulk if weight.present? && weight >= factory.bulk_weight_threshold
    factory.price_per_kg
  end

  def amount_basis
    return :weight if weight.present?
    return :items if number_of_items.present?
  end

  private

  def recalculate_amount
    self.amount = calculated_amount
  end

  def clear_weight_when_items_only
    self.weight = nil if items_only
  end

  def pick_up_at_not_in_the_past
    earliest = self.class.earliest_pick_up_date
    if pick_up_at.to_date < earliest
      errors.add(:pick_up_at, "must be #{earliest == Date.current ? 'today' : 'tomorrow'} or later")
    end
  end

  def pick_up_at_not_on_weekend
    if pick_up_at.to_date.on_weekend?
      errors.add(:pick_up_at, I18n.t("admin.request.validations.pick_up_at_weekend"))
    end
  end

  def phone_must_be_valid_for_factory_country
    return if phone.blank?
    parsed = Phonelib.parse(phone, factory.phone_country)
    errors.add(:phone, "must be a valid phone number for #{factory.country_code}") unless parsed.valid?
  end

  def address_resolvable_by_google
    return unless Google::Geocoder.api_key.present?

    if Google::Geocoder.find(address: address, city: city).nil?
      errors.add(:address, "не може да бъде намерен в Google Maps. Моля, проверете правописа или въведете по-точно описание.")
    end
  end

  # Date-derived prefix that opens every customer_id, e.g. a 2026-06-08 pickup
  # gives "260608" (the month is coded 4X for Jan–Sep, plain for Oct–Dec).
  def customer_id_prefix
    date = pick_up_at.to_date
    year = date.strftime("%y")
    month = date.month < 10 ? "4#{date.month}" : date.month.to_s
    day = date.strftime("%d")
    "#{year}#{month}#{day}"
  end

  def generate_customer_id
    prefix = customer_id_prefix

    # Pick the first unused suffix for today's prefix rather than `count+1`,
    # which collided whenever today's records had been deleted, backdated, or
    # otherwise didn't form a contiguous 1..N sequence. Exclude this record so
    # renumbering on a date change doesn't count its own (stale) id.
    scope = Request.where("customer_id LIKE ?", "#{prefix}%")
    scope = scope.where.not(id: id) if persisted?
    used = scope.pluck(:customer_id)
                .filter_map { |id| id.delete_prefix(prefix).to_i if id.start_with?(prefix) }
                .to_set
    daily_count = 1
    daily_count += 1 while used.include?(daily_count)

    self.customer_id = "#{prefix}#{daily_count}"
  end

  # When a request is rescheduled to a different day, its customer_id prefix no
  # longer matches the pickup date — reissue it. A same-day time change keeps
  # the prefix, so we skip the renumber in that case.
  def regenerate_customer_id_on_pick_up_change
    return if customer_id.present? && customer_id.start_with?(customer_id_prefix)

    generate_customer_id
  end

  # Unguessable random token used in the public SMS short link (/r/:token).
  # Sequential customer_id stays for internal admin use; this is the only
  # identifier that ever appears in customer-facing URLs.
  def generate_status_token
    loop do
      candidate = SecureRandom.hex(4)
      unless Request.exists?(status_token: candidate)
        self.status_token = candidate
        break
      end
    end
  end
end
