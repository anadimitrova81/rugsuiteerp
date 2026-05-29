class Factory < ApplicationRecord
  SLUG_REGEX = /\A[a-z0-9](?:[a-z0-9\-]{0,30}[a-z0-9])?\z/
  RESERVED_SLUGS = %w[www admin app api auth status mail email support help docs].freeze
  HEX_COLOR_REGEX = /\A#[0-9A-Fa-f]{6}\z/
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/svg+xml].freeze
  LOGO_MAX_BYTES = 2.megabytes
  PRICING_MODES = %w[per_kg per_sqm].freeze

  has_one_attached :logo

  has_many :users,         dependent: :destroy
  has_many :requests,      dependent: :destroy
  has_many :notifications, through: :requests
  has_many :page_visits,   dependent: :destroy

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
  validates :same_day_cutoff_hour, numericality: { only_integer: true, in: 0..23 }
  validates :brand_primary_color,   format: { with: HEX_COLOR_REGEX, message: "must be a hex value like #0f3f7e" }, allow_blank: true
  validates :brand_secondary_color, format: { with: HEX_COLOR_REGEX, message: "must be a hex value like #0f3f7e" }, allow_blank: true
  validate  :logo_must_be_image_under_2mb

  # True if this factory prices by area (m²) instead of by weight (kg).
  def per_sqm?
    pricing_mode == "per_sqm"
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

  def earliest_pick_up_date
    now = Time.current.in_time_zone(time_zone)
    now.hour < same_day_cutoff_hour ? now.to_date : now.to_date + 1
  end

  private

  def normalize_slug
    self.slug = slug.to_s.strip.downcase.presence
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
end
