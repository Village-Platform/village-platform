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

      verb = @outcome == :resolved ? "resolve" : "dismiss"
      ApplicationRecord.transaction do
        # Row by row (not update_all), so each report gets its version.
        reports = Report.open.where(subject: @subject).lock.to_a
        Audit.operation("report.#{verb}", actor: @admin) do
          reports.each do |report|
            report.update!(status: @outcome, resolved_by: @admin, resolution_note: @note, resolved_at: Time.current)
          end
        end
        act if @outcome == :resolved && @action
        reports.size
      end
    end

    private

    def act
      case @action
      when "suspend_firm"
        Audit.operation("firm.suspend", actor: @admin) { @subject.update!(status: :suspended) }
      when "remove_medium"
        Audit.operation("firm_medium.destroy", actor: @admin) { @subject.destroy! }
      when "unpublish_article"
        Audit.operation("article.unpublish", actor: @admin) { @subject.update!(review_state: :pending, published_at: nil) }
      end
    end
  end
end
