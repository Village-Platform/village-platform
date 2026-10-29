module Api
  module V1
    class FirmsController < BaseController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_firm, only: %i[show update destroy]

      # GET /api/v1/firms?category_id=1&q=pharmacy&mine=true
      # GET /api/v1/categories/:category_id/firms
      #
      # Lists show only visible firms, to everyone. The policy scope still decides what a user may
      # open: owners and the super admin reach pending / suspended firms through show, and owners
      # list all of their own with mine=true.
      def index
        scope = policy_scope(Firm).includes(category: { icon_image_attachment: :blob }).order(:name, :id)
        scope = params[:mine].present? && current_user ? scope.where(owner_id: current_user.id) : scope.visible
        scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.search(params[:q]) if params[:q].present?

        records, meta = paginate(scope)
        render_collection(records, meta, FirmSerializer, user: current_user)
      end

      def show
        authorize @firm
        render_record(@firm, FirmSerializer, user: current_user)
      end

      def create
        authorize Firm
        return render_error(:forbidden, "subscription_required") unless current_user.can_add_firm?

        firm = current_user.firms.create!(permitted_attributes(Firm))
        render_record(firm, FirmSerializer, status: :created, user: current_user)
      end

      # An owner's edit of an active firm sends it back for review (Firms::Update).
      def update
        authorize @firm
        Firms::Update.call(firm: @firm, editor: current_user, attributes: permitted_attributes(@firm))
        render_record(@firm, FirmSerializer, user: current_user)
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
