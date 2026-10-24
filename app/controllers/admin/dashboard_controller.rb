module Admin
  class DashboardController < BaseController
    def show
      @stats = {
        pending_subscriptions: Subscription.pending.count,
        current_subscriptions: Subscription.current.count,
        pending_firms: Firm.pending.count,
        visible_firms: Firm.visible.count,
        users: User.count,
        published_articles: Article.published.count
      }
      @pending = Subscription.pending.includes(:user, :subscription_plan).order(:created_at).limit(10)
      @expiring = Subscription.current.where(ends_at: ..7.days.from_now)
                              .includes(:user, :subscription_plan).order(:ends_at).limit(10)
      @pending_firms = Firm.pending.includes(:category, :owner).order(:created_at).limit(10)
    end
  end
end
