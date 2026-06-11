class ProcessStep < ApplicationRecord
  acts_as_tenant :factory

  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  IMAGE_MAX_BYTES = 5.megabytes

  belongs_to :factory
  has_one_attached :image

  validates :title, presence: true
  validate :image_must_be_valid

  scope :ordered, -> { order(:position, :id) }

  before_create :assign_position

  private

  # Append new steps after the current last one. Queries are tenant-scoped by
  # acts_as_tenant, so this counts only the current factory's steps.
  def assign_position
    self.position = (ProcessStep.maximum(:position) || 0) + 1 if position.to_i.zero?
  end

  def image_must_be_valid
    return unless image.attached?
    unless IMAGE_CONTENT_TYPES.include?(image.content_type)
      errors.add(:image, "must be a PNG, JPEG or WebP image")
    end
    if image.byte_size > IMAGE_MAX_BYTES
      errors.add(:image, "must be smaller than 5 MB")
    end
  end
end
