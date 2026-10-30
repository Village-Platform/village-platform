module Admin
  class FirmsController < BaseController
    before_action :set_firm, only: %i[show edit update destroy approve suspend restore destroy_fully]
    before_action :load_form_options, only: %i[new create edit update]

    def index
      scope = case params[:deleted]
      when "only" then Firm.only_deleted
      when "all" then Firm.with_deleted
      else Firm.all
      end

      scope = scope.includes(:category, :owner).order(created_at: :desc, id: :desc)
      scope = scope.where(status: params[:status]) if Firm.statuses.key?(params[:status])
      scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
      scope = scope.where("firms.name ILIKE ?", like(params[:q])) if params[:q].present?

      @categories = Category.ordered
      @deleted_count = Firm.only_deleted.count
      @firms, @meta = paginate(filter(scope))
      @visible_ids = Firm.visible.where(id: @firms.map(&:id)).pluck(:id).to_set
    end

    def show
      @visible = Firm.visible.exists?(@firm.id)
    end

    def new
      @firm = Firm.new(status: :active, owner: prefilled_owner || current_admin)
    end

    def create
      @firm = Firm.new(firm_params)
      if @firm.save
        redirect_to admin_firm_path(@firm), notice: "تم إضافة النشاط."
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

    def restore
      restore_and_redirect(@firm, admin_firm_path(@firm))
    end

    def destroy_fully
      destroy_fully_and_redirect(@firm, admin_firms_path)
    end

    def approve
      @firm.update!(status: :active)
      redirect_back_or_to admin_firm_path(@firm), notice: "تم اعتماد النشاط."
    end

    def suspend
      @firm.update!(status: :suspended)
      redirect_back_or_to admin_firm_path(@firm), notice: "تم إيقاف النشاط."
    end

    private

    def set_firm
      @firm = Firm.with_deleted.find(params[:id])
    end

    def load_form_options
      @categories = Category.ordered
      @owners = User.where(role: %i[firm_admin super_admin]).order(:name)
    end

    # Reached from a user's page: "+ نشاط جديد" carries the owner so it is not picked twice.
    def prefilled_owner
      return if params[:owner_id].blank?

      @owners.find_by(id: params[:owner_id])
    end

    def firm_params
      params.require(:firm).permit(:name, :category_id, :owner_id, :status, :description, :phone, :whatsapp,
                                   :address, :working_hours, :latitude, :longitude)
    end
  end
end
