module Admin
  class NotificationsController < BaseController
    before_action :set_notification, only: %i[show destroy]

    def index
      scope = Notification.includes(:user).latest_first
      scope = scope.where(kind: params[:kind]) if Notification.kinds.key?(params[:kind])
      scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
      if params[:status] == "read"
        scope = scope.where.not(read_at: nil)
      elsif params[:status] == "unread"
        scope = scope.unread
      end
      if params[:q].present?
        scope = scope.joins(:user).where(
          "notifications.title ILIKE :q OR notifications.body ILIKE :q OR users.name ILIKE :q OR users.phone ILIKE :q",
          q: like(params[:q])
        )
      end

      @notifications, @meta = paginate(filter(scope))
    end

    def show; end

    def new
      @notification = Notification.new(kind: :system_announcement)
      @users = User.order(:name)
    end

    def create
      title = params.dig(:notification, :title).to_s.strip
      body = params.dig(:notification, :body).to_s.strip
      kind = params.dig(:notification, :kind).presence || "system_announcement"
      target = params[:target] # "all" or "specific"
      user_id = params.dig(:notification, :user_id)

      if title.blank? || body.blank?
        flash.now[:alert] = "يجب إدخال عنوان الإشعار ونصه."
        @notification = Notification.new(title:, body:, kind:, user_id:)
        @users = User.order(:name)
        return render :new, status: :unprocessable_content
      end

      if target == "all"
        users = User.not_deleted
        count = 0
        Notification.transaction do
          users.find_each do |user|
            Notification.create!(user:, title:, body:, kind:)
            count += 1
          end
        end
        redirect_to admin_notifications_path, notice: "تم إرسال الإشعار لجميع المستخدمين (#{count} مستخدم)."
      else
        user = User.find_by(id: user_id)
        unless user
          flash.now[:alert] = "يجب اختيار المستخدم المستلم."
          @notification = Notification.new(title:, body:, kind:)
          @users = User.order(:name)
          return render :new, status: :unprocessable_content
        end

        Notification.create!(user:, title:, body:, kind:)
        redirect_to admin_notifications_path, notice: "تم إرسال الإشعار للمستخدم #{user.name}."
      end
    end

    def destroy
      destroy_and_redirect(@notification, admin_notifications_path)
    end

    private

    def set_notification
      @notification = Notification.find(params[:id])
    end
  end
end
