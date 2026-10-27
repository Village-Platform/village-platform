module Admin
  # Read-only: audit rows are never edited or deleted from the dashboard.
  class AuditEventsController < BaseController
    requires_permission :super_admin

    def index
      scope = AuditEvent.includes(:actor).latest_first
      scope = scope.where(subject_type: params[:subject_type]) if params[:subject_type].present?
      scope = scope.where(actor_id: params[:actor_id]) if params[:actor_id].present?
      if params[:q].present?
        scope = scope.where("audit_events.subject_label ILIKE :q OR audit_events.action ILIKE :q", q: like(params[:q]))
      end

      @subject_types = AuditEvent.distinct.order(:subject_type).pluck(:subject_type)
      @events, @meta = paginate(scope)
    end
  end
end
