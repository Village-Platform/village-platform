module Api
  module V1
    # The current user's own subscriptions.
    class SubscriptionsController < BaseController
      before_action :authenticate_user!

      def index
        authorize Subscription
        scope = Subscription.where(user_id: current_user.id).includes(:subscription_plan).latest_first
        records, meta = paginate(scope)
        render_collection(records, meta, SubscriptionSerializer)
      end

      def show
        subscription = Subscription.where(user_id: current_user.id).find(params[:id])
        authorize subscription
        render_record(subscription, SubscriptionSerializer)
      end

      # POST /api/v1/subscriptions
      # { "subscription": { "subscription_plan_id", "payment_method": "instapay|vodafone_cash",
      #                     "transaction_reference", "payer_phone", "notes" } }
      def create
        authorize Subscription
        subscription = current_user.subscriptions.create!(permitted_attributes(Subscription))
        render_record(subscription, SubscriptionSerializer, status: :created)
      end
    end
  end
end
