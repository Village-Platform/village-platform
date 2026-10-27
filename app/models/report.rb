# A user's flag on something public. Moderation input only: nothing is hidden until an admin
# resolves it, so a burst of reports cannot take a competitor's firm down.
class Report < ApplicationRecord
  SUBJECT_TYPES = { "firm" => "Firm", "firm_medium" => "FirmMedium", "article" => "Article" }.freeze

  enum :reason, { wrong_info: 0, inappropriate: 1, spam: 2, closed: 3, other: 4 }, validate: true
  enum :status, { open: 0, resolved: 1, dismissed: 2 }, default: :open, validate: true

  belongs_to :reporter, class_name: "User"
  belongs_to :resolved_by, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true

  validates :subject_type, inclusion: { in: SUBJECT_TYPES.values }
  validates :note, length: { maximum: 500 }
  validates :resolution_note, length: { maximum: 300 }
  validates :subject_id, uniqueness: { scope: %i[reporter_id subject_type], conditions: -> { open } }, if: :open?
end
