module Admin
  # Review queue for InstaPay / Vodafone Cash transfers. Uses the same services as the API.
  class SubscriptionsController < BaseController
    requires_permission "subscriptions.review"

    include ActiveStorage::SetCurrent # Disk service URLs for the screenshot redirect

    before_action :set_subscription, only: %i[show screenshot approve reject]

    def index
      scope = Subscription.includes(:user, :subscription_plan).latest_first
      scope = scope.where(status: params[:status]) if Subscription.statuses.key?(params[:status])
      scope = scope.where(payment_method: params[:payment_method]) if Subscription.payment_methods.key?(params[:payment_method])
      if params[:q].present?
        scope = scope.joins(:user).where(
          "subscriptions.transaction_reference ILIKE :q OR subscriptions.payer_phone ILIKE :q OR users.phone ILIKE :q OR users.name ILIKE :q",
          q: like(params[:q])
        )
      end

      @subscriptions, @meta = paginate(scope)
    end

    def show; end

    # Image tag source: checks admin access, then redirects to a 5-minute URL.
    def screenshot
      return head :not_found unless @subscription.payment_screenshot.attached?

      redirect_to @subscription.payment_screenshot.url(expires_in: 5.minutes), allow_other_host: true
    end

    def approve
      Subscriptions::Approve.call(subscription: @subscription, reviewer: current_admin)
      redirect_to admin_subscription_path(@subscription), notice: "تم اعتماد الاشتراك وإشعار صاحب النشاط."
    rescue Subscriptions::ReviewError
      redirect_to admin_subscription_path(@subscription), alert: "تمت مراجعة هذا الاشتراك بالفعل."
    end

    def reject
      reason = params[:reason].to_s.strip
      if reason.blank?
        return redirect_to admin_subscription_path(@subscription), alert: "يجب كتابة سبب الرفض."
      end

      Subscriptions::Reject.call(subscription: @subscription, reviewer: current_admin, reason:)
      redirect_to admin_subscription_path(@subscription), notice: "تم رفض الطلب وإشعار صاحبه."
    rescue Subscriptions::ReviewError
      redirect_to admin_subscription_path(@subscription), alert: "تمت مراجعة هذا الاشتراك بالفعل."
    end

    private

    def set_subscription
      @subscription = Subscription.find(params[:id])
    end
  end
end
