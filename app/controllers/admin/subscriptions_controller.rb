module Admin
  # Subscriptions management: review queue and full manual CRUD for super admin.
  class SubscriptionsController < BaseController
    include ActiveStorage::SetCurrent

    before_action :set_subscription, only: %i[show edit update destroy screenshot approve reject]
    before_action :load_form_options, only: %i[new create edit update]

    def index
      scope = Subscription.includes(:user, :subscription_plan).latest_first
      if params[:status] == "expiring"
        scope = scope.current.where(ends_at: ..7.days.from_now)
      elsif Subscription.statuses.key?(params[:status])
        scope = scope.where(status: params[:status])
      end

      scope = scope.where(payment_method: params[:payment_method]) if Subscription.payment_methods.key?(params[:payment_method])
      scope = scope.where(subscription_plan_id: params[:subscription_plan_id]) if params[:subscription_plan_id].present?

      if params[:q].present?
        scope = scope.joins(:user).where(
          "subscriptions.transaction_reference ILIKE :q OR subscriptions.payer_phone ILIKE :q OR users.phone ILIKE :q OR users.name ILIKE :q",
          q: like(params[:q])
        )
      end

      @plans = SubscriptionPlan.ordered
      @subscriptions, @meta = paginate(filter(scope))
    end

    def show; end

    def new
      user = User.find_by(id: params[:user_id])
      plan = SubscriptionPlan.active.ordered.first
      @subscription = Subscription.new(
        user:,
        subscription_plan: plan,
        payment_method: :instapay,
        amount_cents: plan&.price_cents || 0,
        status: :active,
        starts_at: Time.current,
        ends_at: plan ? Time.current + plan.duration_days.days : 30.days.from_now,
        transaction_reference: "MANUAL-#{SecureRandom.hex(4).upcase}"
      )
    end

    def create
      @subscription = Subscription.new(subscription_params)
      if @subscription.transaction_reference.blank?
        @subscription.transaction_reference = "MANUAL-#{SecureRandom.hex(4).upcase}"
      end
      if @subscription.amount_cents.blank? && @subscription.subscription_plan
        @subscription.amount_cents = @subscription.subscription_plan.price_cents
      end
      if @subscription.status == "active"
        @subscription.reviewed_by = current_admin
        @subscription.reviewed_at = Time.current
        if @subscription.starts_at.blank?
          @subscription.starts_at = Time.current
        end
        if @subscription.ends_at.blank? && @subscription.subscription_plan
          @subscription.ends_at = @subscription.starts_at + @subscription.subscription_plan.duration_days.days
        end
      end

      if @subscription.save
        @subscription.user.update!(role: :firm_admin) if @subscription.active? && @subscription.user.user?
        redirect_to admin_subscription_path(@subscription), notice: "تم إنشاء الاشتراك بنجاح."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      attrs = subscription_params
      if attrs[:status] == "active" && @subscription.reviewed_at.nil?
        attrs[:reviewed_by_id] = current_admin.id
        attrs[:reviewed_at] = Time.current
      end

      if @subscription.update(attrs)
        @subscription.user.update!(role: :firm_admin) if @subscription.active? && @subscription.user.user?
        redirect_to admin_subscription_path(@subscription), notice: "تم تحديث بيانات الاشتراك."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      destroy_and_redirect(@subscription, admin_subscriptions_path)
    end

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

    def load_form_options
      @users = User.order(:name)
      @plans = SubscriptionPlan.ordered
    end

    def subscription_params
      params.require(:subscription).permit(
        :user_id, :subscription_plan_id, :status, :payment_method,
        :amount_cents, :transaction_reference, :payer_phone, :notes,
        :starts_at, :ends_at, :rejection_reason
      )
    end
  end
end
