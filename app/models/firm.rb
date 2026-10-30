class Firm < ApplicationRecord
  # Public: what FirmSerializer shows. `owner` is admin-only — it leads to the owner's phone.
  ransack_tiers public: %w[ id name description phone whatsapp address working_hours status
                            category_id owner_id created_at ],
                admin: %w[ updated_at deleted_at ],
                public_associations: %w[ category ],
                admin_associations: %w[ owner ]

  # pending   -> created by a firm owner, waiting for super admin review
  # active    -> approved
  # suspended -> hidden by a super admin (moderation)
  # Note: an active firm is shown publicly only while its owner has a current subscription.
  acts_as_paranoid

  enum :status, { pending: 0, active: 1, suspended: 2 }, default: :pending, validate: true

  belongs_to :category
  belongs_to :owner, class_name: "User", inverse_of: :firms

  scope :search, ->(term) { where("firms.name ILIKE ?", "%#{sanitize_sql_like(term)}%") }

  # Public listing: approved firms whose owner is subscribed (or is a super admin).
  scope :visible, -> {
    active.where(owner_id: Subscription.current.select(:user_id))
          .or(active.where(owner_id: User.super_admin.select(:id)))
  }

  validates :name, presence: true, length: { maximum: 150 }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true

  def self.ransackable_scopes(auth_object = nil)
    %w[ visible ]
  end
end
