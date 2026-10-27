# Editorial pin of a firm to the app's featured strip for a period (a campaign, a new opening, a
# paid promotion). Time-based like subscriptions: no job flips a flag. Featuring never overrides
# visibility — the firm must still be in Firm.visible to be shown.
class FeaturedPlacement < ApplicationRecord
  MAX_SHOWN = 10

  has_audit_trail

  belongs_to :firm
  belongs_to :created_by, class_name: "User", optional: true

  scope :current, -> { where(starts_at: ..Time.current).where("featured_placements.ends_at > ?", Time.current) }
  scope :upcoming_or_current, -> { where("featured_placements.ends_at > ?", Time.current) }

  validates :starts_at, :ends_at, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :note, length: { maximum: 200 }
  validate :ends_after_start

  private

  def ends_after_start
    errors.add(:ends_at, :invalid) if starts_at && ends_at && ends_at <= starts_at
  end
end
