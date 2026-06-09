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

  ROLES.each { |role| define_method(:"#{role}?") { self.role == role } }
end
