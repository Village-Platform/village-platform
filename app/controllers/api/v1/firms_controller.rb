module Api
  module V1
    class FirmsController < BaseController
      before_action :authenticate_user!, except: %i[index show featured]
      before_action :set_firm, only: %i[show update destroy]

      # GET /api/v1/firms?category_id=1&q=pharmacy&mine=true
      # GET /api/v1/categories/:category_id/firms
      def index
        scope = policy_scope(Firm).includes(category: [ :fields, { icon_image_attachment: :blob } ], media: { file_attachment: :blob }).ranked
        # A parent category lists its children's firms too.
        scope = scope.where(category_id: Category.with_children_ids(params[:category_id])) if params[:category_id].present?
        scope = scope.search(params[:q]) if params[:q].present?
        scope = scope.where(owner_id: current_user.id) if params[:mine].present? && current_user

        records, meta = paginate(scope)
        render_collection(records, meta, FirmSerializer)
      end

      # GET /api/v1/firms/featured — the home screen strip: current placements of visible firms.
      def featured
        firms = Firm.visible.joins(:featured_placements).merge(FeaturedPlacement.current)
                    .includes(category: [ :fields, { icon_image_attachment: :blob } ], media: { file_attachment: :blob })
                    .order("featured_placements.position", "featured_placements.id")
                    .limit(FeaturedPlacement::MAX_SHOWN).to_a.uniq
        render json: { data: firms.map { FirmSerializer.render(_1) } }
      end

      def show
        authorize @firm
        render_record(@firm, FirmSerializer)
      end

      def create
        authorize Firm
        return render_error(:forbidden, "subscription_required") unless current_user.can_add_firm?

        # The creator owns the firm; a super admin may name another owner or none (owner_id: null).
        attrs = permitted_attributes(Firm)
        firm = Firm.new(attrs)
        firm.owner = current_user unless attrs.key?(:owner_id) # only super admins may send owner_id
        firm.save!
        render_record(firm, FirmSerializer, status: :created)
      end

      def update
        authorize @firm
        audited("firm.update") { @firm.update!(permitted_attributes(@firm)) }
        render_record(@firm, FirmSerializer)
      end

      def destroy
        authorize @firm
        audited("firm.destroy") { @firm.destroy! }
        head :no_content
      end

      private

      def set_firm
        @firm = policy_scope(Firm).find(params[:id])
      end
    end
  end
end
