# Append-only record of a privileged write. The app inserts these rows and never updates or
# deletes them, so there is no update path here on purpose.
class AuditEvent < ApplicationRecord
  SOURCES = %w[admin api cron system].freeze

  belongs_to :actor, class_name: "User", optional: true

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }
  scope :for_subject, ->(record) { where(subject_type: record.class.name, subject_id: record.id) }

  validates :action, :subject_type, :subject_id, presence: true
  validates :source, inclusion: { in: SOURCES }

  def readonly? = persisted?
end
