# A message to one or more topics: one FCM send (topic or condition) plus an inbox row for each
# signed-in recipient. Delivered by DeliverCampaignJob; see Campaigns::Schedule.
class NotificationCampaign < ApplicationRecord
  MAX_TOPICS = 5 # FCM allows at most 5 topics in one condition
  TITLE_LENGTH = 100

  enum :status, { scheduled: 0, sending: 1, sent: 2, failed: 3, canceled: 4 }, validate: true

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :article, optional: true
  has_many :campaign_topics, dependent: :delete_all
  has_many :topics, through: :campaign_topics
  has_many :notifications, foreign_key: :campaign_id, inverse_of: :campaign, dependent: :nullify

  scope :latest_first, -> { order(scheduled_at: :desc, id: :desc) }

  validates :title, presence: true, length: { maximum: TITLE_LENGTH }
  validates :body, presence: true, length: { maximum: 500 }
  validates :scheduled_at, presence: true
  validates :screen, inclusion: { in: Notifications::Destination::ADMIN_SCREENS }
  validate :topic_count
  validate :destination_exists, if: -> { scheduled? && (new_record? || will_save_change_to_target_id? || will_save_change_to_screen?) }

  def destination
    Notifications::Destination.new(screen:, id: target_id)
  end

  def cancel!(reason = nil)
    unless scheduled?
      errors.add(:status, "لا يمكن إلغاء حملة ليست مجدولة.")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: :canceled, last_error: reason)
  end

  private

  def topic_count
    count = topics.size
    errors.add(:topics, "اختر من موضوع واحد إلى #{MAX_TOPICS} مواضيع.") unless count.between?(1, MAX_TOPICS)
  end

  def destination_exists
    error = destination.error
    errors.add(:target_id, error) if error
  end
end
