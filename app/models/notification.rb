class Notification < ApplicationRecord
  acts_as_tenant :factory

  KINDS = %w[price_quote].freeze
  CHANNELS = %w[sms].freeze
  STATUSES = %w[sent failed].freeze

  belongs_to :request

  validates :kind, inclusion: { in: KINDS }
  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }

  scope :sms_log, -> { order(sent_at: :desc) }
end
