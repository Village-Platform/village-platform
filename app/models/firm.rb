class Firm < ApplicationRecord
  # pending   -> created by a firm owner, waiting for super admin review (or subscription later)
  # active    -> visible to everyone
  # suspended -> hidden (e.g. expired subscription)
  enum :status, { pending: 0, active: 1, suspended: 2 }, default: :pending, validate: true

  belongs_to :category
  belongs_to :owner, class_name: "User", inverse_of: :firms

  scope :search, ->(term) { where("firms.name ILIKE ?", "%#{sanitize_sql_like(term)}%") }

  validates :name, presence: true, length: { maximum: 150 }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
end
