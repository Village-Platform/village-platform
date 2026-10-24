class UserPolicy < ApplicationPolicy
  def index?  = super_admin?
  def update? = super_admin?
end
