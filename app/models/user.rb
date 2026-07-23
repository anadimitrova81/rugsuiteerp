class User < ApplicationRecord
  acts_as_tenant :factory

  has_secure_password

  ROLES = %w[admin courier operator coordinator]

  # Translated labels via I18n. Use `User.role_label(role)` and
  # `User.role_labels` instead of the legacy frozen hash.
  def self.role_label(role)
    I18n.t("admin.user.roles.#{role}")
  end

  def self.role_labels
    ROLES.index_with { |r| role_label(r) }
  end

  def self.role_description(role)
    I18n.t("admin.user.role_descriptions.#{role}")
  end

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false, scope: :factory_id },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: ROLES }

  # Hard cap: refuse to add a user once the factory has hit its plan's seat
  # limit. The admin controller guards this earlier with a friendly message;
  # this validation is the backstop for every other creation path.
  validate :within_plan_user_limit, on: :create

  ROLES.each { |role| define_method(:"#{role}?") { self.role == role } }

  private

  def within_plan_user_limit
    tenant = factory || ActsAsTenant.current_tenant
    return unless tenant&.user_limit_reached?

    errors.add(:base, I18n.t("admin.limits.user.reached_generic"))
  end
end
