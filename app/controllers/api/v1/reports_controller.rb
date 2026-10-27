module Api
  module V1
    # POST /api/v1/reports
    #   { "report": { "subject_type": "firm" | "firm_medium" | "article", "subject_id", "reason", "note" } }
    class ReportsController < BaseController
      before_action :authenticate_user!
      rate_limit to: 10, within: 1.hour, by: -> { current_user&.id || request.remote_ip },
                 with: -> { render_error(:too_many_requests, "too_many_requests") }

      def create
        authorize Report
        attrs = permitted_attributes(Report)
        report = current_user.reports.create!(subject: visible_subject(attrs), reason: attrs[:reason], note: attrs[:note])
        render_record(report, ReportSerializer, status: :created)
      end

      private

      # Only what the reporter can see can be reported (an unknown or hidden id is a 404).
      def visible_subject(attrs)
        id = attrs.require(:subject_id)
        case attrs.require(:subject_type)
        when "firm" then policy_scope(Firm).find(id)
        when "article" then policy_scope(Article).find(id)
        when "firm_medium" then FirmMedium.where(firm_id: policy_scope(Firm).select(:id)).find(id)
        else raise ActionController::ParameterMissing, :subject_type
        end
      end
    end
  end
end
