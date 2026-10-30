class Article < ApplicationRecord
  acts_as_paranoid
  # `author` is admin-only: it leads to a User, and through it to a phone number.
  ransack_tiers public: %w[ id title kind published_at ],
                admin: %w[ body author_id created_at updated_at deleted_at ],
                admin_associations: %w[ author ]

  enum :kind, { news: 0, article: 1, announcement: 2 }, default: :news, validate: true

  belongs_to :author, class_name: "User", inverse_of: :articles, with_deleted: true

  scope :published, -> { where(published_at: ..Time.current) }
  scope :latest_first, -> { order(published_at: :desc, id: :desc) }

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true

  def published?
    published_at.present? && published_at <= Time.current
  end

  def self.ransackable_scopes(auth_object = nil)
    %w[ published ]
  end
end
