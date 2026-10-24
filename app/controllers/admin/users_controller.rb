module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[show edit update]

    def index
      scope = User.order(created_at: :desc, id: :desc)
      scope = scope.where(role: params[:role]) if User.roles.key?(params[:role])
      if params[:q].present?
        scope = scope.where("users.name ILIKE :q OR users.phone ILIKE :q OR users.email ILIKE :q", q: like(params[:q]))
      end
      @users, @meta = paginate(scope)
    end

    def show
      @current_subscription = @user.current_subscription
      @subscriptions = @user.subscriptions.includes(:subscription_plan).latest_first.limit(20)
      @firms = @user.firms.includes(:category).order(:name)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      if @user.save
        redirect_to admin_user_path(@user), notice: "تم إضافة المستخدم."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      attrs = user_params
      attrs = attrs.except(:password) if attrs[:password].blank? # keep the current password

      if @user == current_admin && attrs[:role].present? && attrs[:role] != "super_admin"
        @user.errors.add(:role, "لا يمكنك إزالة صلاحيتك بنفسك")
        return render :edit, status: :unprocessable_content
      end

      if @user.update(attrs)
        redirect_to admin_user_path(@user), notice: "تم حفظ التعديلات."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :phone, :email, :role, :password)
    end
  end
end
