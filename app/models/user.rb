class User < ApplicationRecord
  acts_as_tenant :factory

  has_secure_password

  ROLES = %w[admin courier operator coordinator]
  ROLE_LABELS = {
    "admin" => "Администратор",
    "courier" => "Куриер",
    "operator" => "Оператор",
    "coordinator" => "Координатор",
  }.freeze

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false, scope: :factory_id },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: ROLES }

  ROLES.each { |role| define_method(:"#{role}?") { self.role == role } }
end
