module Admin
  # Review queue for InstaPay / Vodafone Cash transfers. Uses the same services as the API.
  class SubscriptionsController < BaseController
    requires_permission "subscriptions.review"

    include ActiveStorage::SetCurrent # Disk service URLs for the screenshot redirect

    CSV_COLUMNS = {
      "id" => :id.to_proc, "الاسم" => ->(s) { s.user.name }, "الهاتف" => ->(s) { s.user.phone },
      "الباقة" => ->(s) { s.subscription_plan.name }, "المبلغ (ج.م)" => ->(s) { s.amount_cents / 100.0 },
      "طريقة الدفع" => :payment_method.to_proc, "رقم العملية" => :transaction_reference.to_proc,
      "رقم المحوِّل" => :payer_phone.to_proc, "الحالة" => :status.to_proc, "الوضع" => :state.to_proc,
      "يبدأ" => :starts_at.to_proc, "ينتهي" => :ends_at.to_proc, "تاريخ الطلب" => :created_at.to_proc
    }.freeze

    before_action :set_subscription, only: %i[show screenshot approve reject]

    def index
      scope = Subscription.includes(:user, :subscription_plan)
      # The pending tab is a queue: oldest first, so nothing waits forever at the bottom.
      scope = params[:status] == "pending" ? scope.order(:created_at, :id) : scope.latest_first
      scope = scope.where(status: params[:status]) if Subscription.statuses.key?(params[:status])
      scope = scope.where(payment_method: params[:payment_method]) if Subscription.payment_methods.key?(params[:payment_method])
      if params[:q].present?
        scope = scope.joins(:user).where(
          "subscriptions.transaction_reference ILIKE :q OR subscriptions.payer_phone ILIKE :q OR users.phone ILIKE :q OR users.name ILIKE :q",
          q: like(params[:q])
        )
      end

      return export_csv(scope, "subscriptions", CSV_COLUMNS) if request.format.csv?

      @subscriptions, @meta = paginate(scope)
    end

    def show
      @signals = Subscriptions::DuplicateSignals.call(@subscription)
    end

    # Image tag source: checks admin access, then redirects to a 5-minute URL.
    def screenshot
      return head :not_found unless @subscription.payment_screenshot.attached?

      redirect_to @subscription.payment_screenshot.url(expires_in: 5.minutes), allow_other_host: true
    end

    def approve
      Subscriptions::Approve.call(subscription: @subscription, reviewer: current_admin,
                                  reconciliation_note: params[:reconciliation_note].to_s.strip)
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
