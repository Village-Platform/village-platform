class FirmPolicy < ApplicationPolicy
  BASE_ATTRIBUTES = %i[category_id name description phone whatsapp address latitude longitude working_hours].freeze

  def index?   = true
  def show?    = true
  def create?  = user&.can_manage_firms? || false
  def update?  = super_admin? || owner?
  def destroy? = super_admin? || owner?

  # Only super admins can change the status (approve / suspend).
  def permitted_attributes
    super_admin? ? BASE_ATTRIBUTES + [ :status ] : BASE_ATTRIBUTES
  end

  private

  def owner?
    user.present? && record.owner_id == user.id
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
