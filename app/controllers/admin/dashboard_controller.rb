module Admin
  class DashboardController < BaseController
    def show
      @stats = {
        pending_subscriptions: Subscription.pending.count,
        current_subscriptions: Subscription.current.count,
        expiring_soon: expiring.count,
        pending_firms: Firm.pending.count,
        firms: Firm.count,
        users: User.count,
        published_articles: Article.published.count
      }
      # Ordered so the view can take the maximum off the front instead of scanning.
      @firms_by_category = Firm.visible.joins(:category).group("categories.name").count.sort_by { |_, n| -n }
      @pending = Subscription.pending.includes(:user, :subscription_plan).order(:created_at).limit(10)
      @expiring = expiring.includes(:user, :subscription_plan).order(:ends_at).limit(10)
      @pending_firms = Firm.pending.includes(:category, :owner).order(:created_at).limit(10)
    end

    private

    def expiring
      Subscription.current.where(ends_at: ..7.days.from_now)
    end
  end
end
