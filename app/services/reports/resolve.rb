module Reports
  # Closes every open report on one subject at once, optionally acting on the subject:
  # suspending a firm, removing a medium, or sending an article back to review.
  class Resolve
    ACTIONS = {
      "suspend_firm" => "Firm",
      "remove_medium" => "FirmMedium",
      "unpublish_article" => "Article"
    }.freeze

    def self.call(**) = new(**).call

    # outcome: :resolved or :dismissed
    def initialize(subject:, admin:, outcome:, action: nil, note: nil)
      @subject = subject
      @admin = admin
      @outcome = outcome.to_sym
      @action = action.presence
      @note = note.presence
    end

    def call
      raise ArgumentError, "unknown outcome" unless %i[resolved dismissed].include?(@outcome)
      raise ArgumentError, "action does not fit the subject" if @action && ACTIONS[@action] != @subject.class.name

      ApplicationRecord.transaction do
        count = Report.open.where(subject: @subject).update_all(
          status: Report.statuses[@outcome], resolved_by_id: @admin.id, resolution_note: @note,
          resolved_at: Time.current, updated_at: Time.current
        )
        verb = @outcome == :resolved ? "resolve" : "dismiss"
        Audit.record(actor: @admin, action: "report.#{verb}", subject: @subject,
                     changes: { "open_reports" => [ count, 0 ], "action" => [ nil, @action ] })
        act if @outcome == :resolved && @action
        count
      end
    end

    private

    def act
      case @action
      when "suspend_firm"
        @subject.update!(status: :suspended)
        Audit.record(actor: @admin, action: "firm.suspend", subject: @subject)
      when "remove_medium"
        Audit.record(actor: @admin, action: "firm_medium.destroy", subject: @subject, changes: Audit.snapshot(@subject))
        @subject.destroy!
      when "unpublish_article"
        @subject.update!(review_state: :pending, published_at: nil)
        Audit.record(actor: @admin, action: "article.update", subject: @subject)
      end
    end
  end
end
