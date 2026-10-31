module Admin
  class DevicesController < BaseController
    before_action :set_device, only: %i[show edit update destroy]

    def index
      scope = Device.includes(:user).order(last_seen_at: :desc, id: :desc)
      scope = scope.where(platform: params[:platform]) if Device::PLATFORMS.include?(params[:platform])
      if params[:q].present?
        scope = scope.left_joins(:user).where(
          "devices.installation_id ILIKE :q OR devices.token ILIKE :q OR users.name ILIKE :q OR users.phone ILIKE :q",
          q: like(params[:q])
        )
      end

      @devices, @meta = paginate(filter(scope))
    end

    def show
      @topics = @device.topics.order(:name)
      @subscriptions = @device.topic_subscriptions.includes(:topic).order(created_at: :desc)
    end

    def new
      @device = Device.new(platform: "android")
      load_users
    end

    def create
      @device = Device.new(device_params)
      if @device.save
        redirect_to admin_device_path(@device), notice: "تم إضافة الجهاز."
      else
        load_users
        render :new, status: :unprocessable_content
      end
    end

    def edit
      load_users
    end

    def update
      if @device.update(device_params)
        redirect_to admin_device_path(@device), notice: "تم حفظ تعديلات الجهاز."
      else
        load_users
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      destroy_and_redirect(@device, admin_devices_path)
    end

    private

    def set_device
      @device = Device.find(params[:id])
    end

    def load_users
      @users = User.not_deleted.order(:name)
    end

    def device_params
      params.require(:device).permit(:installation_id, :token, :platform, :locale, :app_version, :user_id)
    end
  end
end
