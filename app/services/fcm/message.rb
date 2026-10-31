module Fcm
  # Builds the parts of an FCM HTTP v1 message. Client#send_to_* add the target (token, topic or
  # condition) to the payload.
  module Message
    module_function

    OPERATORS = { or: " || ", and: " && " }.freeze

    # Everything but the target. FCM accepts only string data values.
    def payload(title:, body:, data:)
      {
        notification: { title:, body: },
        data: data.to_h { |key, value| [ key.to_s, value.to_s ] },
        android: { priority: "high" }
      }
    end

    # "'news' in topics || 'owners' in topics". FCM allows at most 5 topics in one condition.
    def condition_for(topic_keys, operator: :or)
      topic_keys.map { |key| "'#{key}' in topics" }.join(OPERATORS.fetch(operator))
    end
  end
end
