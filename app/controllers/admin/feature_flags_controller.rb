module Admin
  class FeatureFlagsController < BaseController
    before_action :set_flag, only: %i[edit update destroy toggle]

    def index
      @flags = FeatureFlag.ordered
    end

    def new
      @flag = FeatureFlag.new
    end

    def create
      @flag = FeatureFlag.new(flag_params)
      if @flag.save
        redirect_to admin_feature_flags_path, notice: "تم إضافة الميزة."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @flag.update(flag_params.except(:key))
        redirect_to admin_feature_flags_path, notice: "تم حفظ التعديلات."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def toggle
      @flag.update!(enabled: !@flag.enabled)
      redirect_to admin_feature_flags_path, notice: @flag.enabled ? "تم تفعيل الميزة." : "تم إيقاف الميزة."
    end

    # Removing a flag turns its feature off in the apps (they read a missing flag as off).
    def destroy
      destroy_and_redirect(@flag, admin_feature_flags_path)
    end

    private

    def set_flag
      @flag = FeatureFlag.find(params[:id])
    end

    def flag_params
      params.require(:feature_flag).permit(:key, :description, :enabled)
    end
  end
end
