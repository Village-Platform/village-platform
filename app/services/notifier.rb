# Creates in-app notifications. Text is rendered in the default locale (Arabic).
# A dedupe_key makes the call idempotent: the same reminder is never created twice.
module Notifier
  def self.notify(user:, kind:, dedupe_key: nil, data: {}, **interpolations)
    return if dedupe_key && Notification.exists?(dedupe_key:)

    I18n.with_locale(I18n.default_locale) do
      Notification.create!(
        user:,
        kind:,
        dedupe_key:,
        data:,
        title: I18n.t("notifications.#{kind}.title", **interpolations),
        body: I18n.t("notifications.#{kind}.body", **interpolations)
      )
    end
  rescue ActiveRecord::RecordNotUnique
    nil # another worker created it first
  end
end
