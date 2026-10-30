module Fcm
  # Builds the "message" object of the FCM HTTP v1 send request.
  module Message
    module_function

    # target: { token: } | { topic: } | { condition: }. FCM accepts only string data values.
    def build(target:, title:, body:, data:)
      {
        **target,
        notification: { title:, body: },
        data: data.to_h { |key, value| [ key.to_s, value.to_s ] },
        android: { priority: "high" }
      }
    end

    # One topic is addressed directly; several need a condition (FCM allows up to 5 in one).
    def target_for_topics(keys)
      return { topic: keys.first } if keys.one?

      { condition: keys.map { |key| "'#{key}' in topics" }.join(" || ") }
    end
  end
end
