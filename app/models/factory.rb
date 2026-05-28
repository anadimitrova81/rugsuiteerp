class Factory < ApplicationRecord
  SLUG_REGEX = /\A[a-z0-9](?:[a-z0-9\-]{0,30}[a-z0-9])?\z/
  RESERVED_SLUGS = %w[www admin app api auth status mail email support help docs].freeze

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
            numericality: { greater_than_or_equal_to: 0 }
  validates :same_day_cutoff_hour, numericality: { only_integer: true, in: 0..23 }

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
end
