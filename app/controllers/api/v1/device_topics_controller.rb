module Api
  module V1
    # Opt in or out of a public topic. Signed in: the subscription belongs to the user, so it
    # follows them to every phone. Guest: it belongs to this install.
    class DeviceTopicsController < BaseController
      before_action :set_device_and_topic

      # PUT /api/v1/devices/:device_installation_id/topics/:key
      def update
        TopicSubscription.find_or_create_by!(topic: @topic, **subscriber)
        sync
        render json: { data: TopicSerializer.render(@topic, subscribed_keys: [ @topic.key ]) }
      end

      # DELETE /api/v1/devices/:device_installation_id/topics/:key
      # Signed in, this also clears a subscription the phone made as a guest, or the topic would
      # stay on through the device row.
      def destroy
        rows = TopicSubscription.where(topic: @topic, device: @device)
        rows = rows.or(TopicSubscription.where(topic: @topic, user: current_user)) if current_user
        rows.delete_all
        sync
        render json: { data: TopicSerializer.render(@topic, subscribed_keys: @device.reload.topic_keys) }
      end

      private

      def set_device_and_topic
        @device = Device.find_by!(installation_id: params[:device_installation_id])
        raise Devices::OwnershipError if @device.user_id && @device.user_id != current_user&.id

        @topic = Topic.listed.find_by!(key: params[:key])
      end

      def subscriber
        current_user ? { user: current_user } : { device: @device }
      end

      def sync
        devices = current_user ? current_user.devices.to_a | [ @device ] : [ @device ]
        devices.each { |device| SyncDeviceTopicsJob.perform_later(device.id, topic_ids: [ @topic.id ]) }
      end
    end
  end
end
