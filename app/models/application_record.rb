class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # PaperTrail, plus the label the audit page shows (kept after the record is deleted).
  # Options pass through to has_paper_trail (skip:, ignore:, ...).
  def self.has_audit_trail(**options)
    has_paper_trail(**options, meta: { item_label: ->(record) { Audit.label_for(record) } })
  end
end
