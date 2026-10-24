module Api
  module V1
    class FirmsController < BaseController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_firm, only: %i[show update destroy]

      # GET /api/v1/firms?category_id=1&q=pharmacy&mine=true
      # GET /api/v1/categories/:category_id/firms
      def index
        scope = policy_scope(Firm).includes(:category).order(:name, :id)
        scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.search(params[:q]) if params[:q].present?
        scope = scope.where(owner_id: current_user.id) if params[:mine].present? && current_user

        records, meta = paginate(scope)
        render_collection(records, meta, FirmSerializer)
      end

      def show
        authorize @firm
        render_record(@firm, FirmSerializer)
      end

      def create
        authorize Firm
        return render_error(:forbidden, "subscription_required") unless current_user.can_add_firm?

        firm = current_user.firms.create!(permitted_attributes(Firm))
        render_record(firm, FirmSerializer, status: :created)
      end

      def update
        authorize @firm
        @firm.update!(permitted_attributes(@firm))
        render_record(@firm, FirmSerializer)
      end

      def destroy
        authorize @firm
        @firm.destroy!
        head :no_content
      end

      private

      def set_firm
        @firm = policy_scope(Firm).find(params[:id])
      end
    end
  end
end
