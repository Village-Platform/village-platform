# Tells PaperTrail who is acting and from where, and labels writes with a business operation.
# Including controllers define #audit_source and #audit_actor.
module Auditing
  extend ActiveSupport::Concern

  included do
    before_action :set_paper_trail_whodunnit
  end

  private

  def user_for_paper_trail
    audit_actor&.id
  end

  def info_for_paper_trail
    { source: audit_source, ip: request.remote_ip, request_id: request.request_id }
  end

  # Names the versions the block writes; returns the block's result.
  #   audited("firm.suspend") { @firm.update!(status: :suspended) }
  def audited(operation, &)
    Audit.operation(operation, &)
  end
end
