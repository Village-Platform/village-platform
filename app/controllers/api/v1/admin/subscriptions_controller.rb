module Api
  module V1
    module Admin
      # Super admin review queue for InstaPay / Vodafone Cash transfers.
      class SubscriptionsController < BaseController
        before_action :authenticate_user!
        before_action :set_subscription, only: %i[show approve reject]

        # GET /api/v1/admin/subscriptions?status=pending
        def index
          authorize Subscription, :review?
          scope = Subscription.includes(:subscription_plan, :user).latest_first
          scope = scope.where(status: params[:status]) if Subscription.statuses.key?(params[:status])

          records, meta = paginate(scope)
          render json: { data: records.map { SubscriptionSerializer.render(_1, include_user: true) }, meta: }
        end

        def show
          render_admin(@subscription)
        end

        # PATCH /api/v1/admin/subscriptions/:id/approve
        def approve
          render_admin(Subscriptions::Approve.call(subscription: @subscription, reviewer: current_user))
        end

        # PATCH /api/v1/admin/subscriptions/:id/reject  { "reason": "..." }
        def reject
          reason = params.require(:reason)
          render_admin(Subscriptions::Reject.call(subscription: @subscription, reviewer: current_user, reason:))
        end

        private

        def set_subscription
          @subscription = Subscription.find(params[:id])
          authorize @subscription, :review?
        end

        def render_admin(subscription)
          render json: { data: SubscriptionSerializer.render(subscription, include_user: true) }
        end
      end
    end
  end
end
