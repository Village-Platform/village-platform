module Api
  module V1
    # Topics the app lists for opt-in. "subscribed" reflects this install (X-Installation-Id header)
    # and the signed-in user; an unknown header is only a hint, so it is not an error.
    class TopicsController < BaseController
      # GET /api/v1/topics
      def index
        device = Device.find_by(installation_id: request.headers["X-Installation-Id"]) if request.headers["X-Installation-Id"]
        keys = subscribed_keys(device)
        render json: { data: Topic.listed.ordered.map { |topic| TopicSerializer.render(topic, subscribed_keys: keys) } }
      end

      private

      def subscribed_keys(device)
        keys = device ? device.topic_keys : []
        keys += Topic.where(id: current_user.topic_subscriptions.select(:topic_id)).pluck(:key) if current_user
        keys
      end
    end
  end
end
