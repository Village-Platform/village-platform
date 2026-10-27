class FirmMediumPolicy < ApplicationPolicy
  # Listing goes through policy_scope(Firm): media of an invisible firm is invisible.
  def index?   = true
  def create?  = super_admin? || owner?
  def update?  = super_admin? || owner?
  def destroy? = super_admin? || owner?

  def permitted_attributes
    %i[caption position]
  end

  private

  def owner?
    user.present? && record.firm.owner_id == user.id
  end
end
