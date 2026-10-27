module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: %i[edit update destroy]

    def index
      @categories = Category.with_attached_icon_image.ordered
      @firm_counts = Firm.group(:category_id).count
    end

    def new
      @category = Category.new(position: (Category.maximum(:position) || 0) + 1)
    end

    def create
      @category = Category.new(category_params)
      if @category.save
        redirect_to admin_categories_path, notice: "تم إضافة القسم."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @category.update(category_params)
        @category.icon_image.purge if remove_icon_image?
        redirect_to admin_categories_path, notice: "تم حفظ التعديلات."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      destroy_and_redirect(@category, admin_categories_path)
    end

    private

    def set_category
      @category = Category.find(params[:id])
    end

    # "Remove image" checkbox; ignored when a new image is uploaded in the same request.
    def remove_icon_image?
      params.dig(:category, :remove_icon_image) == "1" && params.dig(:category, :icon_image).blank?
    end

    def category_params
      params.require(:category).permit(:name, :description, :icon, :icon_image, :position, :active)
    end
  end
end
