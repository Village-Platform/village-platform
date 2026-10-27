# Records who changed what. Call it inside the same transaction as the write it describes, so a
# rolled-back action leaves no row and a committed one always has one.
#
#   Audit.record(actor: current_admin, action: "firm.suspend", subject: firm)
module Audit
  # Never copied into an audit row.
  IGNORED_ATTRIBUTES = %w[password_digest created_at updated_at].freeze
  LABEL_ATTRIBUTES = %i[name title transaction_reference key].freeze

  def self.record(actor:, action:, subject:, changes: nil)
    AuditEvent.create!(
      actor:,
      action:,
      subject_type: subject.class.name,
      subject_id: subject.id,
      subject_label: label_for(subject),
      changeset: (changes || changes_of(subject)).except(*IGNORED_ATTRIBUTES),
      source: Current.source || "system",
      ip: Current.ip,
      request_id: Current.request_id
    )
  end

  # The attributes the last save changed, as { "attr" => [old, new] }.
  def self.changes_of(record)
    record.saved_changes.except(*IGNORED_ATTRIBUTES)
  end

  # What a deleted record looked like, as { "attr" => [old, nil] }.
  def self.snapshot(record)
    record.attributes.except("id", *IGNORED_ATTRIBUTES).transform_values { |value| [ value, nil ] }
  end

  def self.label_for(subject)
    attribute = LABEL_ATTRIBUTES.find { |name| subject.respond_to?(name) && subject.public_send(name).present? }
    attribute ? subject.public_send(attribute).to_s.truncate(150) : "##{subject.id}"
  end
end
