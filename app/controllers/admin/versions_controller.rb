module Admin
  # The audit trail (PaperTrail versions). Read-only: versions are never edited or deleted here.
  class VersionsController < BaseController
    requires_permission :super_admin

    def index
      scope = PaperTrail::Version.order(created_at: :desc, id: :desc)
      scope = scope.where(item_type: params[:subject_type]) if params[:subject_type].present?
      scope = scope.where(whodunnit: params[:actor_id].to_s) if params[:actor_id].present?
      if params[:q].present?
        scope = scope.where("versions.item_label ILIKE :q OR versions.operation ILIKE :q", q: like(params[:q]))
      end

      @subject_types = PaperTrail::Version.distinct.order(:item_type).pluck(:item_type)
      @versions, @meta = paginate(scope)
    end
  end
end
