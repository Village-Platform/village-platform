# An announcement a super admin (or staff with notifications.send) sent to an audience.
class Broadcast < ApplicationRecord
  AUDIENCES = {
    "everyone" => "كل المستخدمين",
    "firm_admins" => "أصحاب الأنشطة",
    "expiring" => "مشتركون ينتهي اشتراكهم خلال أيام",
    "category_owners" => "أصحاب أنشطة تصنيف معيّن"
  }.freeze

  belongs_to :actor, class_name: "User"

  validates :audience, inclusion: { in: AUDIENCES.keys }
  validates :title, presence: true, length: { maximum: 120 }
  validates :body, presence: true, length: { maximum: 1000 }
  validates :idempotency_key, presence: true
  validate :audience_params_present

  # The users this broadcast reaches, as a relation (never loaded whole).
  def recipients
    case audience
    when "everyone" then User.all
    when "firm_admins" then User.firm_admin
    when "expiring"
      User.where(id: Subscription.current.where(ends_at: ..days.days.from_now).select(:user_id))
    when "category_owners"
      User.where(id: Firm.where(category_id: audience_params["category_id"]).select(:owner_id))
    else User.none
    end
  end

  def days = audience_params["days"].to_i

  private

  def audience_params_present
    errors.add(:audience_params, :blank) if audience == "expiring" && !days.between?(1, 60)
    errors.add(:audience_params, :blank) if audience == "category_owners" && audience_params["category_id"].blank?
  end
end
