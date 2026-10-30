# Never exposes installation_id or token: the installation_id is the install's own secret.
class DeviceSerializer
  def self.render(device)
    {
      platform: device.platform,
      locale: device.locale,
      app_version: device.app_version,
      user_attached: device.user_id.present?,
      topics: device.topic_keys
    }
  end
end
