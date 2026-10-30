module Admin
  class TopicsController < BaseController
    before_action :set_topic, only: %i[show edit update destroy]
    before_action :keep_system_topic, only: %i[edit update destroy]

    def index
      @topics = Topic.ordered
      @member_counts = TopicSubscription.group(:topic_id).count
    end

    def show
      @members, @meta = paginate(User.where(id: @topic.topic_subscriptions.select(:user_id)).order(:name))
      @device_counts = Device.where(user_id: @members.map(&:id)).group(:user_id).count
      @guest_devices = @topic.topic_subscriptions.where.not(device_id: nil).count
      return if params[:q].blank?

      @candidates = User.not_deleted.where.not(id: @topic.topic_subscriptions.select(:user_id).where.not(user_id: nil))
                        .where("users.name ILIKE :q OR users.phone ILIKE :q", q: like(params[:q])).order(:name).limit(20)
    end

    def new
      @topic = Topic.new
    end

    def create
      @topic = Topic.new(topic_params)
      if @topic.save
        redirect_to admin_topic_path(@topic), notice: "تم إضافة الموضوع."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @topic.update(topic_params.except(:key))
        redirect_to admin_topic_path(@topic), notice: "تم حفظ التعديلات."
      else
        render :edit, status: :unprocessable_content
      end
    end

    # Members' tokens stay in the FCM topic until FCM drops them, but nothing is sent to a topic
    # that no longer exists here.
    def destroy
      destroy_and_redirect(@topic, admin_topics_path)
    end

    private

    def set_topic
      @topic = Topic.find(params[:id])
    end

    def keep_system_topic
      redirect_to admin_topic_path(@topic), alert: "لا يمكن تعديل موضوع النظام." if @topic.system?
    end

    def topic_params
      params.require(:topic).permit(:key, :name, :description, :public)
    end
  end
end
