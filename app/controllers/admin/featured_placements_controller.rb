module Admin
  # Featuring can be a paid promotion, so it stays with super admins.
  class FeaturedPlacementsController < BaseController
    requires_permission :super_admin

    def index
      @placements = FeaturedPlacement.upcoming_or_current.includes(:firm).order(:starts_at, :position)
    end

    def create
      firm = Firm.find(params[:firm_id])
      placement = firm.featured_placements.build(placement_params.merge(created_by: current_admin))
      if audited("featured_placement.feature") { placement.save }
        redirect_to admin_firm_path(firm), notice: "تم تمييز النشاط."
      else
        redirect_to admin_firm_path(firm), alert: placement.errors.full_messages.to_sentence
      end
    end

    def destroy
      placement = FeaturedPlacement.find(params[:id])
      destroy_and_redirect(placement, admin_featured_placements_path)
    end

    private

    def placement_params
      params.require(:featured_placement).permit(:starts_at, :ends_at, :position, :note)
    end
  end
end
