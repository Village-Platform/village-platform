class SubscriptionPolicy < ApplicationPolicy
  def index?   = user.present?
  def show?    = super_admin? || record.user_id == user&.id
  def create?  = user.present? && !super_admin?
  def review?  = super_admin?

  def permitted_attributes
    %i[subscription_plan_id payment_method transaction_reference payer_phone notes]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if super_admin?
      return scope.none if user.nil?

      scope.where(user_id: user.id)
    end
  end
end
