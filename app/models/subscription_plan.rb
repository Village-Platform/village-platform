class SubscriptionPlan < ApplicationRecord
  ransack_tiers public: %w[ id name description price_cents duration_days max_firms position active ],
                admin: %w[ created_at updated_at price_egp ],
                admin_associations: %w[ subscriptions ]

  # Money is stored in piasters; filtering in pounds stops "500" meaning 5 EGP.
  ransacker :price_egp do
    Arel.sql("(subscription_plans.price_cents / 100.0)")
  end

  has_many :subscriptions, dependent: :restrict_with_error

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :duration_days, numericality: { only_integer: true, greater_than: 0 }
  validates :max_firms, numericality: { only_integer: true, greater_than: 0 }
end
