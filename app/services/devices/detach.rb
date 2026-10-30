module Devices
  # Logout, or another user signing in on the same phone. The device becomes a guest, and its token
  # leaves the previous user's topics so the next person on the phone does not get their pushes.
  class Detach
    def self.call(device:)
      user_topic_ids = TopicSubscription.where(user_id: device.user_id).pluck(:topic_id)
      device.update!(user: nil)
      SyncDeviceTopicsJob.perform_later(device.id, topic_ids: user_topic_ids) if user_topic_ids.any?
      device
    end
  end
end
