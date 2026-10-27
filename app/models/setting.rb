# Operational values a super admin changes without a deploy. Keys are declared here with a type
# and default; unknown keys are rejected. Secrets and payment destinations stay in ENV on
# purpose: an editable payment account would let a stolen admin session redirect money.
class Setting < ApplicationRecord
  SCHEMA = {
    "support_phone" => { type: :string, default: nil, client: true, label: "رقم الدعم" },
    # Android versionCode values. Below the minimum, the app shows a blocking update screen.
    "min_android_version" => { type: :integer, default: 1, client: true, label: "أقل إصدار أندرويد مسموح (versionCode)" },
    "latest_android_version" => { type: :integer, default: 1, client: true, label: "أحدث إصدار أندرويد (versionCode)" },
    "banner" => { type: :string, default: nil, client: true, label: "شريط تنبيه في التطبيق" }
  }.freeze

  CACHE_KEY = "settings/all/v1".freeze
  CACHE_TTL = 60.seconds # with several web pods, this is how stale another pod can be

  has_audit_trail

  belongs_to :updated_by, class_name: "User", optional: true

  validates :key, inclusion: { in: SCHEMA.keys }, uniqueness: true

  after_commit { Rails.cache.delete(CACHE_KEY) }

  def self.get(key)
    definition = SCHEMA.fetch(key.to_s)
    all_values.fetch(key.to_s, definition[:default])
  end

  def self.all_values
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { pluck(:key, :value).to_h }
  end

  def self.client_config
    SCHEMA.select { |_, definition| definition[:client] }.keys.index_with { get(_1) }
  end

  # Casts form input to the declared type; blank means "back to the default".
  def self.cast(key, raw)
    return nil if raw.blank?

    SCHEMA.fetch(key)[:type] == :integer ? Integer(raw.to_s, 10) : raw.to_s.strip
  end
end
