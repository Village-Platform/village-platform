module Admin
  class SubscriptionPlansController < BaseController
    before_action :set_plan, only: %i[edit update destroy]

    def index
      @plans = SubscriptionPlan.ordered
    end

    def new
      @plan = SubscriptionPlan.new(duration_days: 30, max_firms: 1)
    end

    def create
      @plan = SubscriptionPlan.new(plan_params)
      if audited("subscription_plan.create", @plan) { @plan.save }
        redirect_to admin_subscription_plans_path, notice: "تم إضافة الباقة."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if audited("subscription_plan.update", @plan) { @plan.update(plan_params) }
        redirect_to admin_subscription_plans_path, notice: "تم حفظ التعديلات."
      else
        render :edit, status: :unprocessable_content
      end
    end

    # Plans that were already purchased can't be deleted — deactivate them instead.
    def destroy
      destroy_and_redirect(@plan, admin_subscription_plans_path)
    end

    private

    def set_plan
      @plan = SubscriptionPlan.find(params[:id])
    end

    # The form takes the price in EGP; it is stored in piasters.
    def plan_params
      permitted = params.require(:subscription_plan)
                        .permit(:name, :description, :price, :duration_days, :max_firms, :max_images_per_firm,
                                :max_videos_per_firm, :max_video_seconds, :max_articles_per_month, :priority,
                                :position, :active)
      price = permitted.delete(:price)
      permitted[:price_cents] = (BigDecimal(price.to_s) * 100).round if price.present?
      permitted
    rescue ArgumentError
      permitted.merge(price_cents: nil)
    end
  end
end
