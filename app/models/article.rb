class Article < ApplicationRecord
  enum :kind, { news: 0, article: 1, announcement: 2 }, default: :news, validate: true
  # Moderation, separate from publishing: a draft is still published_at: nil. Super admins'
  # articles are approved on write; subscribers' wait in pending for Articles::Review.
  enum :review_state, { approved: 0, pending: 1, rejected: 2 }, default: :approved, validate: true

  # Kinds a subscriber may write. Announcements speak for the platform.
  SUBSCRIBER_KINDS = %w[news article].freeze

  belongs_to :author, class_name: "User", inverse_of: :articles
  belongs_to :firm, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_one_attached :cover_image

  scope :published, -> { where(published_at: ..Time.current) }
  # Public feed: published, approved, and written by a super admin or a current subscriber —
  # the same rule as Firm.visible, so an expired subscriber's articles hide until renewal.
  scope :visible, -> {
    published.approved.where(author_id: User.super_admin.select(:id))
             .or(published.approved.where(author_id: Subscription.current.select(:user_id)))
  }
  scope :latest_first, -> { order(published_at: :desc, id: :desc) }

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true, length: { maximum: 20_000 }
  validates :rejection_reason, length: { maximum: 300 }
  validate :firm_belongs_to_author

  def published?
    published_at.present? && published_at <= Time.current
  end

  private

  def firm_belongs_to_author
    return if firm.nil? || author&.super_admin? || firm.owner_id == author_id

    errors.add(:firm, :invalid)
  end
end
