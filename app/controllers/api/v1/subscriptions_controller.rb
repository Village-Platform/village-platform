module Api
  module V1
    # The current user's own subscriptions.
    class SubscriptionsController < BaseController
      include ScreenshotRedirect

      before_action :authenticate_user!
      before_action :set_subscription, only: %i[show payment_screenshot]

      def index
        authorize Subscription
        scope = own_subscriptions.includes(:subscription_plan).with_attached_payment_screenshot.latest_first
        records, meta = paginate(scope)
        render_collection(records, meta, SubscriptionSerializer)
      end

      def show
        render_record(@subscription, SubscriptionSerializer)
      end

      # POST /api/v1/subscriptions  (JSON, or multipart/form-data when sending a screenshot)
      # subscription[subscription_plan_id], [payment_method] instapay|vodafone_cash,
      # [transaction_reference], [payer_phone], [notes], [payment_screenshot] (PNG/JPEG/WEBP, max 5MB)
      def create
        authorize Subscription
        subscription = current_user.subscriptions.create!(permitted_attributes(Subscription))
        render_record(subscription, SubscriptionSerializer, status: :created)
      end

      # GET /api/v1/subscriptions/:id/payment_screenshot -> 302 to a 5-minute URL
      def payment_screenshot
        redirect_to_payment_screenshot(@subscription)
      end

      private

      def own_subscriptions
        Subscription.where(user_id: current_user.id)
      end

      def set_subscription
        @subscription = own_subscriptions.find(params[:id])
        authorize @subscription, :show?
      end
    end
  end
end
