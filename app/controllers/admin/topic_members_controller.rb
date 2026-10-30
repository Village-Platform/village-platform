module Admin
  # Admin assignment of users to a topic. The subscription belongs to the user, so it follows them
  # to every phone they sign in on; each change resyncs their devices with FCM.
  class TopicMembersController < BaseController
    before_action :set_topic

    def create
      user = User.not_deleted.find(params[:user_id])
      TopicSubscription.find_or_create_by!(topic: @topic, user:)
      sync(user)
      redirect_to admin_topic_path(@topic), notice: "تمت إضافة #{user.name} إلى الموضوع."
    end

    def destroy
      user = User.find(params[:id])
      TopicSubscription.where(topic: @topic, user:).delete_all
      sync(user)
      redirect_to admin_topic_path(@topic), notice: "تمت إزالة #{user.name} من الموضوع."
    end

    private

    def set_topic
      @topic = Topic.find(params[:topic_id])
      redirect_to admin_topic_path(@topic), alert: "موضوع النظام يضم كل الأجهزة تلقائيًا." if @topic.system?
    end

    def sync(user)
      user.devices.ids.each { |device_id| SyncDeviceTopicsJob.perform_later(device_id, topic_ids: [ @topic.id ]) }
    end
  end
end
