module Admin
  class SearchController < BaseController
    def index
      results = GlobalSearch.call(query: params[:q], scope: params[:scope].presence || "all")
      render json: results.map { |result| serialize(result) }
    end

    private

    def serialize(result)
      { type: result.type, title: result.title, subtitle: result.subtitle, url: record_path(result.record) }
    end

    def record_path(record)
      case record
      when Firm, User, Subscription then polymorphic_path([ :admin, record ])
      when Article then edit_admin_article_path(record)
      when Category then edit_admin_category_path(record)
      when SubscriptionPlan then edit_admin_subscription_plan_path(record)
      end
    end
  end
end
