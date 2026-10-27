class Firm < ApplicationRecord
  # pending   -> created by a firm owner, waiting for super admin review
  # active    -> approved
  # suspended -> hidden by a super admin (moderation)
  # Note: an active firm is shown publicly only while its owner has a current subscription.
  enum :status, { pending: 0, active: 1, suspended: 2 }, default: :pending, validate: true

  belongs_to :category
  belongs_to :owner, class_name: "User", inverse_of: :firms
  # Media has no meaning without its firm, so it is the one association that cascades.
  has_many :media, -> { ordered }, class_name: "FirmMedium", inverse_of: :firm, dependent: :destroy

  scope :search, ->(term) { where("firms.name ILIKE ?", "%#{sanitize_sql_like(term)}%") }

  # Public listing: approved firms whose owner is subscribed (or is a super admin).
  scope :visible, -> {
    active.where(owner_id: Subscription.current.select(:user_id))
          .or(active.where(owner_id: User.super_admin.select(:id)))
  }

  # Public listing order: subscribers above the super admin's imported places, higher plan
  # priority first, then by name with the id as a stable tiebreak for pagination. Computed per
  # query, because subscriptions expire by time and a stored rank would go stale at expiry.
  scope :ranked, -> {
    owner_plan = sanitize_sql([ <<~SQL.squish, { active: Subscription.statuses[:active], now: Time.current } ])
      LEFT JOIN LATERAL (
        SELECT MAX(subscription_plans.priority) AS priority
        FROM subscriptions
        JOIN subscription_plans ON subscription_plans.id = subscriptions.subscription_plan_id
        WHERE subscriptions.user_id = firms.owner_id AND subscriptions.status = :active
          AND subscriptions.starts_at <= :now AND subscriptions.ends_at > :now
      ) owner_plan ON TRUE
    SQL
    joins(owner_plan).order(Arel.sql("COALESCE(owner_plan.priority, -1) DESC"), :name, :id)
  }

  validates :name, presence: true, length: { maximum: 150 }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
end
