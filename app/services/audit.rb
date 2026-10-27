# The audit trail is PaperTrail: every audited model has `has_audit_trail`, and each save writes a
# version (who, what changed, when, from which front door) in the same transaction as the change.
# This module only adds the business operation name to the versions a block writes:
#
#   Audit.operation("firm.suspend") { firm.update!(status: :suspended) }
#   Audit.operation("subscription.approve", actor: reviewer) { ... }   # services pass the actor
module Audit
  LABEL_ATTRIBUTES = %i[name title transaction_reference key].freeze

  def self.operation(name, actor: nil, &block)
    options = { controller_info: (PaperTrail.request.controller_info || {}).merge(operation: name) }
    options[:whodunnit] = actor.id if actor
    PaperTrail.request(options, &block)
  end

  # What a version's item was called (stored in versions.item_label).
  def self.label_for(record)
    attribute = LABEL_ATTRIBUTES.find { |name| record.respond_to?(name) && record.public_send(name).present? }
    attribute ? record.public_send(attribute).to_s.truncate(150) : "##{record.id}"
  end
end
