class Article < ApplicationRecord
  acts_as_paranoid

  enum :kind, { news: 0, article: 1, announcement: 2 }, default: :news, validate: true

  belongs_to :author, class_name: "User", inverse_of: :articles

  scope :published, -> { where(published_at: ..Time.current) }
  scope :latest_first, -> { order(published_at: :desc, id: :desc) }

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true

  def published?
    published_at.present? && published_at <= Time.current
  end
end
