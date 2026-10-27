class ArticlePolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  # The monthly quota itself is checked by Articles::Submit.
  def create?  = super_admin? || user&.entitlements&.max_articles_per_month.to_i.positive?
  def update?  = super_admin? || author?
  def destroy? = super_admin? || author?
  def review?  = super_admin?

  # Subscribers cannot set published_at: it is set when their article is approved.
  def permitted_attributes
    super_admin? ? %i[title body kind published_at firm_id] : %i[title body kind firm_id]
  end

  private

  def author?
    user.present? && record.author_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if super_admin?
      return scope.visible if user.nil?

      scope.visible.or(scope.where(author_id: user.id))
    end
  end
end
