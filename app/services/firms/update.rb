module Firms
  # Edits a firm. An owner's change to an approved (active) firm sends it back for review: it turns
  # pending, drops out of the public lists, and returns once the super admin approves it again, so
  # a firm cannot change its name or phone after approval unseen. Edits by the super admin, edits
  # of pending or suspended firms, and saves that change nothing keep the status.
  class Update
    def self.call(firm:, editor:, attributes:) = new(firm:, editor:, attributes:).call

    def initialize(firm:, editor:, attributes:)
      @firm = firm
      @editor = editor
      @attributes = attributes
    end

    def call
      # with_lock reloads the row, so the attributes are assigned inside it: an approval saved at
      # the same moment is either seen here or waits for this save, never overwritten.
      @firm.with_lock do
        @firm.assign_attributes(@attributes)
        @firm.status = :pending if needs_review?
        @firm.save!
      end
      @firm
    end

    private

    def needs_review?
      !@editor.super_admin? && @firm.active? && @firm.changed?
    end
  end
end
