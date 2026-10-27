class FirmPolicy < ApplicationPolicy
  BASE_ATTRIBUTES = %i[category_id name description phone whatsapp address latitude longitude working_hours].freeze

  def index?   = true
  def show?    = true
  # Plan quota is checked separately (User#can_add_firm?, 403 subscription_required).
  def create?  = user&.can_manage_firms? || false
  # Super admins manage every firm, owned or not. An owner manages theirs only while subscribed.
  def update?  = super_admin? || (owner? && subscribed!)
  # An owner may always remove their own firm, even after the subscription ended.
  def destroy? = super_admin? || owner?

  # Only super admins can change the status (approve / suspend) and the owner (or clear it).
  # custom_fields: { "<key>" => value } for the category's fields (see CategoryField).
  def permitted_attributes
    attributes = BASE_ATTRIBUTES + [ { custom_fields: {} } ]
    super_admin? ? attributes + %i[status owner_id] : attributes
  end

  private

  def owner?
    user.present? && record.owner_id.present? && record.owner_id == user.id
  end

  def subscribed!
    user.subscribed? || raise(SubscriptionRequired, query: :update?, record:, policy: self)
  end

  class Scope < ApplicationPolicy::Scope
    # Public: visible firms. Owners also see all of their own firms.
    def resolve
      return scope.all if super_admin?
      return scope.visible if user.nil?

      scope.visible.or(scope.where(owner_id: user.id))
    end
  end
end
