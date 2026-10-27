module Admin
  class CategoriesController < BaseController
    requires_permission "categories.manage"

    before_action :set_category, only: %i[edit update destroy]
    before_action :load_parents, only: %i[new create edit update]

    def index
      # Parents first, each followed by its children.
      categories = Category.with_attached_icon_image.includes(:parent).ordered.to_a
      children = categories.select(&:parent_id).group_by(&:parent_id)
      @categories = categories.reject(&:parent_id).flat_map { |parent| [ parent, *children.fetch(parent.id, []) ] }
      @firm_counts = Firm.group(:category_id).count
    end

    def new
      @category = Category.new(position: (Category.maximum(:position) || 0) + 1)
    end

    def create
      @category = Category.new(category_params)
      if audited("category.create") { @category.save }
        Categories::OptimizeIcon.call(@category)
        redirect_to admin_categories_path, notice: "تم إضافة التصنيف."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if audited("category.update") { @category.update(category_params) }
        @category.icon_image.purge if remove_icon_image?
        Categories::OptimizeIcon.call(@category)
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
    def load_parents
      @parents = Category.top_level.ordered.where.not(id: @category&.id)
    end

    def remove_icon_image?
      params.dig(:category, :remove_icon_image) == "1" && params.dig(:category, :icon_image).blank?
    end

    def category_params
      params.require(:category).permit(:name, :description, :icon, :icon_image, :position, :active, :parent_id)
    end
  end
end
