class Factory < ApplicationRecord
  SLUG_REGEX = /\A[a-z0-9](?:[a-z0-9\-]{0,30}[a-z0-9])?\z/
  RESERVED_SLUGS = %w[www admin app api auth status mail email support help docs].freeze
  HEX_COLOR_REGEX = /\A#[0-9A-Fa-f]{6}\z/
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/svg+xml].freeze
  LOGO_MAX_BYTES = 2.megabytes
  # The hero image is a photo (no SVG) and can be larger than the logo.
  HERO_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  HERO_MAX_BYTES = 5.megabytes
  PRICING_MODES = %w[per_kg per_sqm].freeze
  PLANS = %w[free starter pro].freeze

  # Caps per plan. `nil` means unlimited. Subscribing to a plan that's stricter
  # than current usage doesn't block existing data — it just makes the limit
  # visible to the admin. Hard gating (refusing to create the 31st request on
  # the free plan) is a separate piece of work.
  PLAN_LIMITS = {
    "free"    => { monthly_orders: 30,   users: 5   },
    "starter" => { monthly_orders: 200,  users: 20  },
    "pro"     => { monthly_orders: 1000, users: nil },
  }.freeze

  has_one_attached :logo
  has_one_attached :hero_image

  has_many :users,         dependent: :destroy
  has_many :requests,      dependent: :destroy
  has_many :notifications, through: :requests
  has_many :page_visits,   dependent: :destroy
  has_many :process_steps, dependent: :destroy

  validates :slug, presence: true,
                   uniqueness: { case_sensitive: false },
                   format: { with: SLUG_REGEX },
                   exclusion: { in: RESERVED_SLUGS }
  validates :name, presence: true
  validates :country_code,   presence: true, length: { is: 2 }
  validates :phone_country,  presence: true, length: { is: 2 }
  validates :currency,       presence: true, length: { is: 3 }
  validates :default_locale, presence: true
  validates :timezone,       presence: true
  validate  :timezone_must_be_valid

  validates :price_per_kg, :price_per_kg_bulk, :bulk_weight_threshold, :price_per_item,
            :price_per_sqm, :price_per_sqm_bulk, :bulk_area_threshold,
            numericality: { greater_than_or_equal_to: 0 }
  validates :pricing_mode, inclusion: { in: PRICING_MODES }
  validates :plan, inclusion: { in: PLANS }
  validates :same_day_cutoff_hour, numericality: { only_integer: true, in: 0..23 }
  validates :brand_primary_color,   format: { with: HEX_COLOR_REGEX, message: "must be a hex value like #0f3f7e" }, allow_blank: true
  validates :brand_secondary_color, format: { with: HEX_COLOR_REGEX, message: "must be a hex value like #0f3f7e" }, allow_blank: true
  validate  :logo_must_be_image_under_2mb
  validate  :hero_image_must_be_valid

  # True if this factory prices by area (m²) instead of by weight (kg).
  def per_sqm?
    pricing_mode == "per_sqm"
  end

  def free?
    plan == "free"
  end

  def monthly_order_limit
    PLAN_LIMITS.dig(plan, :monthly_orders)
  end

  def user_limit
    PLAN_LIMITS.dig(plan, :users)
  end

  # Convenience usage counts; assume we're already inside the right
  # ActsAsTenant scope (which the admin pages always are).
  def monthly_orders_used
    requests.where("created_at >= ?", Time.current.beginning_of_month).count
  end

  def users_count
    users.count
  end

  # Plan gating. Both return false when the plan is unlimited (limit is nil).
  # `>=` because when usage already equals the cap, the *next* create is the
  # one that would exceed it. Assumes the current ActsAsTenant scope, like the
  # usage counts above.
  def order_limit_reached?
    monthly_order_limit.present? && monthly_orders_used >= monthly_order_limit
  end

  def user_limit_reached?
    user_limit.present? && users_count >= user_limit
  end

  # The active per-unit rate, considering the chosen pricing_mode. Used by
  # the tenant home page's pricing display.
  def price_per_unit
    per_sqm? ? price_per_sqm : price_per_kg
  end

  def price_per_unit_bulk
    per_sqm? ? price_per_sqm_bulk : price_per_kg_bulk
  end

  def bulk_unit_threshold
    per_sqm? ? bulk_area_threshold : bulk_weight_threshold
  end

  # I18n key for the unit label ("kg" or "m²") — view templates do
  # `t("units.#{factory.pricing_unit_key}")`.
  def pricing_unit_key
    per_sqm? ? "sqm" : "kg"
  end

  before_validation :normalize_slug

  def time_zone
    ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
  end

  # Public social links for the home page. Facebook/Instagram accept a full URL
  # (we prepend https:// if the admin omitted the scheme). Viber accepts either
  # a viber://… / https:// link or a plain phone number, which we turn into a
  # chat deep link. Each returns nil when unset, so the view can skip it.
  def facebook_link  = normalize_social_url(facebook_url)
  def instagram_link = normalize_social_url(instagram_url)

  def viber_link
    return if viber_url.blank?
    value = viber_url.strip
    return value if value.match?(%r{\A(https?|viber)://}i)

    digits = value.gsub(/[^\d+]/, "")
    "viber://chat?number=#{CGI.escape(digits)}" if digits.present?
  end

  # WhatsApp accepts a full link or a phone number, which becomes a wa.me link
  # (digits only — wa.me rejects "+", spaces and punctuation).
  def whatsapp_link
    return if whatsapp_url.blank?
    value = whatsapp_url.strip
    return value if value.match?(%r{\Ahttps?://}i)

    digits = value.gsub(/\D/, "")
    "https://wa.me/#{digits}" if digits.present?
  end

  def earliest_pick_up_date
    now = Time.current.in_time_zone(time_zone)
    now.hour < same_day_cutoff_hour ? now.to_date : now.to_date + 1
  end

  private

  def normalize_slug
    self.slug = slug.to_s.strip.downcase.presence
  end

  # Lets admins paste a bare domain ("facebook.com/acme") or a full URL; we
  # ensure there's a scheme so the link works. Returns nil when unset.
  def normalize_social_url(value)
    return if value.blank?
    value = value.strip
    value.match?(%r{\Ahttps?://}i) ? value : "https://#{value}"
  end

  def timezone_must_be_valid
    return if timezone.blank?
    errors.add(:timezone, "is not a valid IANA timezone") unless ActiveSupport::TimeZone[timezone]
  end

  def logo_must_be_image_under_2mb
    return unless logo.attached?
    unless LOGO_CONTENT_TYPES.include?(logo.content_type)
      errors.add(:logo, "must be a PNG, JPEG, WebP or SVG image")
    end
    if logo.byte_size > LOGO_MAX_BYTES
      errors.add(:logo, "must be smaller than 2 MB")
    end
  end

  def hero_image_must_be_valid
    return unless hero_image.attached?
    unless HERO_CONTENT_TYPES.include?(hero_image.content_type)
      errors.add(:hero_image, "must be a PNG, JPEG or WebP image")
    end
    if hero_image.byte_size > HERO_MAX_BYTES
      errors.add(:hero_image, "must be smaller than 5 MB")
    end
  end
end
