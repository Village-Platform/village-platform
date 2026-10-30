class TopicSerializer
  def self.render(topic, subscribed_keys: [])
    {
      key: topic.key,
      name: topic.name,
      description: topic.description,
      subscribed: subscribed_keys.include?(topic.key)
    }
  end
end
