# An extra field firms in one category fill in (pharmacy: "open 24h"; doctor: "speciality").
# Values live in firms.custom_fields (jsonb): they are only read with their firm, so an
# entity-attribute-value table would cost joins for nothing.
class CategoryField < ApplicationRecord
  enum :kind, { text: 0, boolean: 1, number: 2, choice: 3 }, validate: true

  belongs_to :category, inverse_of: :fields

  scope :ordered, -> { order(:position, :id) }

  validates :key, presence: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }, length: { maximum: 40 },
                  uniqueness: { scope: :category_id }
  validates :label, presence: true, length: { maximum: 80 }
  validate :choice_has_options

  # Form input to the stored value; nil means "not filled".
  def cast(raw)
    return nil if raw.nil? || raw.to_s.strip.empty?

    case kind
    when "boolean" then ActiveModel::Type::Boolean.new.cast(raw)
    when "number" then Float(raw.to_s).then { _1 == _1.to_i ? _1.to_i : _1 }
    else raw.to_s.strip.first(200)
    end
  end

  def as_json(*)
    { key:, label:, kind:, options:, required: }
  end

  private

  def choice_has_options
    return unless choice?

    errors.add(:options, :blank) unless options.is_a?(Array) && options.any?
  end
end
