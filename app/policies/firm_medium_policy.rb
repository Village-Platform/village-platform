class FirmMediumPolicy < ApplicationPolicy
  # Listing goes through policy_scope(Firm): media of an invisible firm is invisible.
  def index?   = true
  # Adding and editing need a current subscription (the plan limit is checked by FirmMedia::Add);
  # an owner may always remove their media.
  def create?  = super_admin? || (owner? && subscribed!)
  def update?  = super_admin? || (owner? && subscribed!)
  def destroy? = super_admin? || owner?

  def permitted_attributes
    %i[caption position]
  end

  private

  def owner?
    user.present? && record.firm.owner_id.present? && record.firm.owner_id == user.id
  end

  def subscribed!
    user.subscribed? || raise(SubscriptionRequired, query: :create?, record:, policy: self)
  end
end
