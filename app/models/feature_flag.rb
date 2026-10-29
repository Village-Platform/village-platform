class FeatureFlag < ApplicationRecord
  # Flags the apps already read. A flag missing from the table is reported with this value, and a
  # client that cannot reach the API treats every flag as off: features fail closed.
  DEFAULTS = { "plans" => false }.freeze

  # The apps look flags up by key, so renaming one would silently turn a feature off for them.
  attr_readonly :key

  scope :ordered, -> { order(:key) }

  validates :key, presence: true, uniqueness: true, length: { maximum: 50 },
                  format: { with: /\A[a-z][a-z0-9_]*\z/ }

  # { "plans" => false, ... } for GET /api/v1/app_config.
  def self.to_h
    DEFAULTS.merge(pluck(:key, :enabled).to_h)
  end

  def self.enabled?(key)
    to_h.fetch(key.to_s, false)
  end
end
