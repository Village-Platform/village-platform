# In-app notification. Later the same records can be pushed through FCM.
class Notification < ApplicationRecord
  enum :kind, {
    subscription_approved: 0,
    subscription_rejected: 1,
    subscription_expiring: 2,
    subscription_expired: 3
  }, validate: true

  belongs_to :user

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
