# One image or video in a firm's gallery. A table rather than has_many_attached, because order,
# caption, per-item moderation and counting per kind all need columns.
class FirmMedium < ApplicationRecord
  enum :kind, { image: 0, video: 1 }, validate: true

  has_audit_trail

  belongs_to :firm, inverse_of: :media
  # Reports point at nothing once their subject is gone.
  has_many :reports, as: :subject, dependent: :delete_all

  # Video goes to object storage when MEDIA_STORAGE_SERVICE is set (see MediaProfile).
  has_one_attached :file

  scope :ordered, -> { order(:position, :id) }

  validates :caption, length: { maximum: 200 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :file_attached

  def profile
    MediaProfile.fetch(video? ? :firm_video : :firm_image)
  end

  # The plan limit that applies to this kind.
  def self.limit_for(kind)
    kind.to_s == "video" ? :max_videos_per_firm : :max_images_per_firm
  end

  private

  def file_attached
    errors.add(:file, :blank) unless file.attached?
  end
end
