class SubscriptionPlanPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = super_admin?
  def update?  = super_admin?
  def destroy? = super_admin?

  def permitted_attributes
    %i[name description price_cents duration_days max_firms max_images_per_firm max_videos_per_firm
       max_video_seconds max_articles_per_month priority position active]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      super_admin? ? scope.all : scope.active
    end
  end
end
