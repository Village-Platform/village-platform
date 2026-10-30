# Pushes one inbox notification to one device. One job per device, so a retry never re-sends to the
# user's other phones. Skips a device that has changed hands since the notification was created.
class PushNotificationJob < ApplicationJob
  include FcmRetries

  queue_as :default

  def perform(notification_id, device_id)
    notification = Notification.find_by(id: notification_id)
    device = Device.find_by(id: device_id)
    return unless notification && device && device.user_id == notification.user_id

    Fcm.client.deliver(message_for(notification, device))
    record_push("ok")
  rescue Fcm::Unregistered
    device.destroy
    Observability::Metrics.increment(:push_tokens_pruned)
    record_push("unregistered")
  rescue Fcm::InvalidArgument => e
    Rails.logger.error("[PushNotificationJob] FCM refused notification_id=#{notification_id}: #{e.message}")
    record_push("invalid")
  end

  private

  def message_for(notification, device)
    Fcm::Message.build(
      target: { token: device.token },
      title: notification.title,
      body: notification.body,
      data: notification.data.merge("notification_id" => notification.id)
    )
  end

  def push_source = "system"
end
