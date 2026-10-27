# Per-request context, filled by the controllers and read by Audit.record.
class Current < ActiveSupport::CurrentAttributes
  attribute :source, :ip, :request_id
end
