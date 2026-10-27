class SubscriptionPlan < ApplicationRecord
  has_audit_trail

  has_many :subscriptions, dependent: :restrict_with_error

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :duration_days, numericality: { only_integer: true, greater_than: 0 }
  validates :max_firms, numericality: { only_integer: true, greater_than: 0 }
  validates :max_images_per_firm, :max_videos_per_firm, :max_video_seconds, :max_articles_per_month,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :priority, numericality: { only_integer: true, in: 0..100 }
end
