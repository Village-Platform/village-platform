class NotificationSerializer
  def self.render(notification)
    {
      id: notification.id,
      kind: notification.kind,
      title: notification.title,
      body: notification.body,
      data: notification.data,
      read: notification.read?,
      read_at: notification.read_at,
      created_at: notification.created_at
    }
  end
end
