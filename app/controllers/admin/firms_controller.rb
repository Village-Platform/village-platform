module Admin
  class FirmsController < BaseController
    before_action :set_firm, only: %i[show edit update destroy approve suspend]
    before_action :load_form_options, only: %i[new create edit update]

    def index
      scope = Firm.includes(:category, :owner).order(created_at: :desc, id: :desc)
      scope = scope.where(status: params[:status]) if Firm.statuses.key?(params[:status])
      scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
      scope = scope.where("firms.name ILIKE ?", like(params[:q])) if params[:q].present?

      @categories = Category.ordered
      @firms, @meta = paginate(scope)
      @visible_ids = Firm.visible.where(id: @firms.map(&:id)).pluck(:id).to_set
    end

    def show
      @visible = Firm.visible.exists?(@firm.id)
    end

    def new
      @firm = Firm.new(status: :active, owner: current_admin)
    end

    def create
      @firm = Firm.new(firm_params)
      if @firm.save
        redirect_to admin_firm_path(@firm), notice: "تم إضافة المنشأة."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @firm.update(firm_params)
        redirect_to admin_firm_path(@firm), notice: "تم حفظ التعديلات."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      destroy_and_redirect(@firm, admin_firms_path)
    end

    def approve
      @firm.update!(status: :active)
      redirect_back_or_to admin_firm_path(@firm), notice: "تم اعتماد المنشأة."
    end

    def suspend
      @firm.update!(status: :suspended)
      redirect_back_or_to admin_firm_path(@firm), notice: "تم إيقاف المنشأة."
    end

    private

    def set_firm
      @firm = Firm.find(params[:id])
    end

    def load_form_options
      @categories = Category.ordered
      @owners = User.where(role: %i[firm_admin super_admin]).order(:name)
    end

    def firm_params
      params.require(:firm).permit(:name, :category_id, :owner_id, :status, :description, :phone, :whatsapp,
                                   :address, :working_hours, :latitude, :longitude)
    end
  end
end
