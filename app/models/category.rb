class Category < ApplicationRecord
  # Formats Android decodes without extra libraries (no SVG). Icons are small tiles, so the cap is low.
  ICON_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  ICON_MAX_SIZE = 512.kilobytes
  # Default artwork for the seed `icon` keys (doctor.png, pharmacy.png, ...).
  DEFAULT_ICONS_DIR = Rails.root.join("db/seeds/category_icons")

  # children_count is a counter cache: not a change anyone made.
  has_audit_trail ignore: %i[children_count]

  has_many :firms, dependent: :restrict_with_error
  # One level deep only: a village directory needs groups, not a taxonomy.
  belongs_to :parent, class_name: "Category", optional: true, counter_cache: :children_count
  has_many :children, class_name: "Category", foreign_key: :parent_id, inverse_of: :parent,
                      dependent: :restrict_with_error
  has_many :fields, -> { ordered }, class_name: "CategoryField", inverse_of: :category, dependent: :destroy

  # The image the apps show. The `icon` string column stays: it is the key older Android
  # versions map to built-in symbols, and it picks the default image in #attach_default_icon!.
  has_one_attached :icon_image

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :top_level, -> { where(parent_id: nil) }

  # The category and its children, for listing a parent's firms.
  def self.with_children_ids(id)
    where(id:).or(where(parent_id: id)).select(:id)
  end

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :icon_image_is_valid
  validate :one_level_deep

  # Public, long-cached URL of the icon (relative to the API host), or nil without an image.
  # `v` changes with the image content, so clients and the CDN can cache each version forever.
  def icon_url
    return unless icon_image.attached?

    Rails.application.routes.url_helpers.icon_api_v1_category_path(self, v: icon_version)
  end

  # Short hex digest of the image content (the blob checksum is base64 MD5).
  def icon_version
    icon_image.checksum.to_s.unpack1("m0").unpack1("H*").first(12) if icon_image.attached?
  end

  # Attaches db/seeds/category_icons/<icon>.png when the category has no image yet.
  # Idempotent; returns true when it attached something.
  def attach_default_icon!
    return false if icon_image.attached? || !icon.to_s.match?(/\A[a-z0-9_]+\z/) # key only, never a path

    path = DEFAULT_ICONS_DIR.join("#{icon}.png")
    return false unless path.file?

    icon_image.attach(io: path.open("rb"), filename: path.basename.to_s, content_type: "image/png")
    Categories::OptimizeIcon.call(self)
    true
  end

  private

  def one_level_deep
    return if parent_id.nil?

    if parent_id == id
      errors.add(:parent, :invalid)
    elsif parent&.parent_id.present? || (persisted? && children.exists?)
      errors.add(:parent, "يجب أن يكون تصنيفًا رئيسيًا، ولا يمكن نقل تصنيف له فروع")
    end
  end

  def icon_image_is_valid
    return unless icon_image.attached?

    blob = icon_image.blob
    unless ICON_CONTENT_TYPES.include?(blob.content_type)
      errors.add(:icon_image, I18n.t("errors.api.invalid_image_type"))
    end
    if blob.byte_size > ICON_MAX_SIZE
      errors.add(:icon_image, I18n.t("errors.api.file_too_large", size: "512KB"))
    end
  end
end
