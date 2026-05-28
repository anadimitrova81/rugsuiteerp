# Creates a new Factory (tenant) + the first admin User in a single
# transaction. Used by the public self-signup form at /signup.
#
# Returns an instance you can interrogate:
#   provisioner = FactoryProvisioner.call(params)
#   provisioner.success? # => true / false
#   provisioner.factory  # the persisted Factory
#   provisioner.admin    # the persisted admin User
#   provisioner.errors   # ActiveModel-compatible errors for form re-rendering
class FactoryProvisioner
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Sensible pricing defaults so the new tenant's home page doesn't render
  # "0.00 / kg" before the admin has had a chance to configure prices. These
  # are intentionally arbitrary — admins should override them on day one.
  DEFAULT_PRICE_PER_KG          = 1.50
  DEFAULT_PRICE_PER_KG_BULK     = 1.35
  DEFAULT_BULK_WEIGHT_THRESHOLD = 50
  DEFAULT_PRICE_PER_ITEM        = 7.50
  DEFAULT_SAME_DAY_CUTOFF_HOUR  = 16

  attribute :name,           :string
  attribute :slug,           :string
  attribute :country_code,   :string
  attribute :admin_email,    :string
  attribute :admin_password, :string

  attr_reader :factory, :admin

  validates :name, presence: true
  validates :slug, presence: true,
                   format: { with: Factory::SLUG_REGEX, message: "may only contain lowercase letters, digits and hyphens" }
  validates :country_code, presence: true
  validate  :country_must_be_supported
  validates :admin_email, presence: true,
                          format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :admin_password, presence: true,
                             length: { minimum: 8, message: "must be at least 8 characters" }

  def self.call(params)
    new(params).tap(&:call)
  end

  def call
    return false unless valid?

    ActiveRecord::Base.transaction do
      @factory = build_factory
      @factory.save!

      ActsAsTenant.with_tenant(@factory) do
        @admin = User.create!(
          email: admin_email,
          password: admin_password,
          role: "admin",
        )
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    propagate_record_errors(e.record)
    false
  end

  def success?
    @factory&.persisted? && @admin&.persisted?
  end

  private

  def build_factory
    defaults = CountryDefaults.for(country_code)
    Factory.new(
      name:                   name,
      slug:                   slug.to_s.downcase.strip,
      country_code:           country_code,
      timezone:               defaults[:timezone],
      currency:               defaults[:currency],
      default_locale:         defaults[:default_locale],
      phone_country:          defaults[:phone_country],
      price_per_kg:           DEFAULT_PRICE_PER_KG,
      price_per_kg_bulk:      DEFAULT_PRICE_PER_KG_BULK,
      bulk_weight_threshold:  DEFAULT_BULK_WEIGHT_THRESHOLD,
      price_per_item:         DEFAULT_PRICE_PER_ITEM,
      same_day_cutoff_hour:   DEFAULT_SAME_DAY_CUTOFF_HOUR,
      service_cities:         [],
    )
  end

  def country_must_be_supported
    return if country_code.blank?
    return if CountryDefaults.supported?(country_code)
    errors.add(:country_code, "is not a supported country yet")
  end

  # Surface ActiveRecord validation errors from the underlying records onto
  # the form's own attributes so the signup view can render them inline.
  def propagate_record_errors(record)
    case record
    when Factory
      record.errors.each { |err| errors.add(map_factory_field(err.attribute), err.message) }
    when User
      record.errors.each { |err| errors.add(map_user_field(err.attribute), err.message) }
    else
      errors.add(:base, "Could not provision factory: #{record.errors.full_messages.to_sentence}")
    end
  end

  def map_factory_field(attr)
    case attr
    when :slug then :slug
    when :name then :name
    else :base
    end
  end

  def map_user_field(attr)
    case attr
    when :email             then :admin_email
    when :password, :password_digest then :admin_password
    else :base
    end
  end
end
