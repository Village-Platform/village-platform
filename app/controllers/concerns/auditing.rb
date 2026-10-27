# Fills the request context Audit.record reads, and wraps a write with its audit row in one
# transaction. Including controllers define #audit_source and #audit_actor.
module Auditing
  extend ActiveSupport::Concern

  included do
    before_action :set_audit_context
  end

  private

  def set_audit_context
    Current.source = audit_source
    Current.ip = request.remote_ip
    Current.request_id = request.request_id
  end

  # The block returns truthy on success; only then is the audit row written.
  #   audited("firm.suspend", @firm) { @firm.update!(status: :suspended) }
  def audited(action, record, changes: nil)
    ApplicationRecord.transaction do
      result = yield
      Audit.record(actor: audit_actor, action:, subject: record, changes:) if result
      result
    end
  end
end
