# In-app notification. Later the same records can be pushed through FCM.
class Notification < ApplicationRecord
  # Public rows are the caller's own (policy scope).
  ransack_tiers public: %w[ id kind title body read_at created_at ],
                admin: %w[ user_id updated_at ],
                admin_associations: %w[ user ]

  enum :kind, {
    subscription_approved: 0,
    subscription_rejected: 1,
    subscription_expiring: 2,
    subscription_expired: 3,
    system_announcement: 4
  }, validate: true

  belongs_to :user, with_deleted: true

  scope :unread, -> { where(read_at: nil) }
  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  validates :title, :body, presence: true

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end
end
