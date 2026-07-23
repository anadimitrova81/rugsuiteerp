# Platform operator (the SaaS owner). NOT tenant-scoped — a PlatformAdmin exists
# above all factories and signs in on the admin.rugsuiteerp.com console, separate
# from tenant Users.
class PlatformAdmin < ApplicationRecord
  has_secure_password

  before_validation :normalize_email

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end
