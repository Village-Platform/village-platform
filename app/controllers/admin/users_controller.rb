module Admin
  class UsersController < BaseController
    requires_permission "users.manage"

    CSV_COLUMNS = {
      "id" => :id.to_proc, "الاسم" => :name.to_proc, "الهاتف" => :phone.to_proc, "البريد" => :email.to_proc,
      "الصلاحية" => :role.to_proc, "تاريخ التسجيل" => :created_at.to_proc
    }.freeze

    before_action :set_user, only: %i[show edit update]
    # Staff with users.manage must not take over an admin account (reset its password) or
    # create one: that would turn a limited permission into full control.
    before_action :protect_admin_accounts, only: %i[edit update]
    helper_method :assignable_roles

    def index
      scope = User.order(created_at: :desc, id: :desc)
      scope = scope.where(role: params[:role]) if User.roles.key?(params[:role])
      if params[:q].present?
        scope = scope.where("users.name ILIKE :q OR users.phone ILIKE :q OR users.email ILIKE :q", q: like(params[:q]))
      end
      return export_csv(scope, "users", CSV_COLUMNS) if request.format.csv?

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
      return render(:new, status: :unprocessable_content) unless role_assignable?(@user)

      if audited("user.create", @user) { @user.save }
        redirect_to admin_user_path(@user), notice: "تم إضافة المستخدم."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      attrs = user_params
      attrs = attrs.except(:password) if attrs[:password].blank? # keep the current password

      if @user == current_admin && attrs[:role].present? && attrs[:role] != current_admin.role
        @user.errors.add(:role, "لا يمكنك إزالة صلاحيتك بنفسك")
        return render :edit, status: :unprocessable_content
      end
      @user.assign_attributes(attrs.slice(:role))
      return render(:edit, status: :unprocessable_content) unless role_assignable?(@user)

      if audited("user.update", @user) { @user.update(attrs) }
        redirect_to admin_user_path(@user), notice: "تم حفظ التعديلات."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def assignable_roles
      current_admin.super_admin? ? User.roles.keys : User.roles.keys - User::ADMIN_ROLES
    end

    def role_assignable?(user)
      return true if assignable_roles.include?(user.role)

      user.errors.add(:role, "لا يمكنك منح هذه الصلاحية")
      false
    end

    def protect_admin_accounts
      return if current_admin.super_admin? || !@user.admin?

      redirect_to admin_user_path(@user), alert: "لا يمكنك تعديل حساب مدير."
    end

    def user_params
      params.require(:user).permit(:name, :phone, :email, :role, :password)
    end
  end
end
