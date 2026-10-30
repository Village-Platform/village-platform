# Creates in-app notifications and pushes them to the user's devices. Text is rendered in the
# default locale (Arabic). A dedupe_key makes the call idempotent: the same reminder is never
# created, or pushed, twice.
#
# The inbox row and the push jobs commit in one transaction: Solid Queue lives in the same
# database, so there is never a push for a rolled-back row nor a row whose push was never queued.
module Notifier
  def self.notify(user:, kind:, dedupe_key: nil, data: {}, destination: Notifications::Destination.none, **interpolations)
    return deduplicated(kind) if dedupe_key && Notification.exists?(dedupe_key:)

    notification = Notification.transaction do
      created = I18n.with_locale(I18n.default_locale) do
        Notification.create!(
          user:,
          kind:,
          dedupe_key:,
          data: data.merge(destination.to_data),
          title: I18n.t("notifications.#{kind}.title", **interpolations),
          body: I18n.t("notifications.#{kind}.body", **interpolations)
        )
      end
      user.devices.ids.each { |device_id| PushNotificationJob.perform_later(created.id, device_id) }
      created
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
