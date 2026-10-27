module Admin
  # Open reports grouped by what they point at, most-reported first.
  class ReportsController < BaseController
    requires_permission "reports.handle"

    def index
      status = Report.statuses.key?(params[:status]) ? params[:status] : "open"
      groups = Report.where(status:).group(:subject_type, :subject_id)
                     .order(Arel.sql("COUNT(*) DESC"), Arel.sql("MIN(reports.created_at)"))
      @status = status
      @groups, @meta = paginate_groups(groups)
      @reports = Report.where(status:, subject_type: @groups.map(&:first), subject_id: @groups.map(&:second))
                       .includes(:reporter, :subject).order(:created_at).group_by { [ _1.subject_type, _1.subject_id ] }
    end

    def resolve
      subject = Report::SUBJECT_TYPES.values.include?(params[:subject_type]) &&
                params[:subject_type].constantize.find(params[:subject_id])
      raise ActiveRecord::RecordNotFound unless subject

      Reports::Resolve.call(subject:, admin: current_admin, outcome: params[:outcome] == "dismissed" ? :dismissed : :resolved,
                            action: params[:subject_action], note: params[:note])
      redirect_to admin_reports_path, notice: "تمت معالجة البلاغات."
    rescue ArgumentError
      redirect_to admin_reports_path, alert: "إجراء غير صالح."
    end

    private

    # [[subject_type, subject_id, count], ...] with the shared pagination meta.
    def paginate_groups(groups)
      page = [ params.fetch(:page, 1).to_i, 1 ].max
      per_page = DEFAULT_PER_PAGE
      total = groups.count.size
      rows = groups.limit(per_page).offset((page - 1) * per_page).pluck(:subject_type, :subject_id, Arel.sql("COUNT(*)"))
      [ rows, { page:, per_page:, total:, total_pages: (total.to_f / per_page).ceil } ]
    end
  end
end
