# Creates in-app notifications. Text is rendered in the default locale (Arabic).
# A dedupe_key makes the call idempotent: the same reminder is never created twice.
module Notifier
  def self.notify(user:, kind:, dedupe_key: nil, data: {}, **interpolations)
    return deduplicated(kind) if dedupe_key && Notification.exists?(dedupe_key:)

    notification = I18n.with_locale(I18n.default_locale) do
      Notification.create!(
        user:,
        kind:,
        dedupe_key:,
        data:,
        title: I18n.t("notifications.#{kind}.title", **interpolations),
        body: I18n.t("notifications.#{kind}.body", **interpolations)
      )
    end
    Observability::Metrics.increment(:notifications_created, kind:)
    notification
  rescue ActiveRecord::RecordNotUnique
    deduplicated(kind) # another worker created it first
  end

  def self.deduplicated(kind)
    Observability::Metrics.increment(:notifications_deduplicated, kind:)
    nil
  end
  private_class_method :deduplicated
end
