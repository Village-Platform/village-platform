class ArticlePolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = super_admin?
  def update?  = super_admin?
  def destroy? = super_admin?

  def permitted_attributes
    %i[title body kind published_at]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      super_admin? ? scope.all : scope.published
    end
  end
end
