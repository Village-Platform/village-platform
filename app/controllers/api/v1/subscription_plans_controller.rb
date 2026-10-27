module Api
  module V1
    class SubscriptionPlansController < BaseController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_plan, only: %i[show update destroy]

      def index
        records, meta = paginate(policy_scope(SubscriptionPlan).ordered)
        render_collection(records, meta, SubscriptionPlanSerializer)
      end

      def show
        authorize @plan
        render_record(@plan, SubscriptionPlanSerializer)
      end

      def create
        authorize SubscriptionPlan
        plan = SubscriptionPlan.new(permitted_attributes(SubscriptionPlan))
        audited("subscription_plan.create") { plan.save! }
        render_record(plan, SubscriptionPlanSerializer, status: :created)
      end

      def update
        authorize @plan
        audited("subscription_plan.update") { @plan.update!(permitted_attributes(@plan)) }
        render_record(@plan, SubscriptionPlanSerializer)
      end

      # Plans with subscriptions can't be deleted; deactivate them instead (active: false).
      def destroy
        authorize @plan
        if audited("subscription_plan.destroy") { @plan.destroy }
          head :no_content
        else
          render_error(:unprocessable_content, "cannot_delete", details: @plan.errors.to_hash(true))
        end
      end

      private

      def set_plan
        @plan = policy_scope(SubscriptionPlan).find(params[:id])
      end
    end
  end
end
