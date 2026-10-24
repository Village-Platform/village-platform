class SubscriptionPlan < ApplicationRecord
  has_many :subscriptions, dependent: :restrict_with_error

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :duration_days, numericality: { only_integer: true, greater_than: 0 }
  validates :max_firms, numericality: { only_integer: true, greater_than: 0 }
end
