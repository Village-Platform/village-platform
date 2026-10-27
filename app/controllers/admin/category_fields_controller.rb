module Admin
  class CategoryFieldsController < BaseController
    requires_permission "categories.manage"

    before_action :set_category

    def create
      field = @category.fields.build(field_params)
      if audited("category_field.create") { field.save }
        redirect_to edit_admin_category_path(@category), notice: "تم إضافة الحقل."
      else
        redirect_to edit_admin_category_path(@category), alert: field.errors.full_messages.to_sentence
      end
    end

    # Removing a field hides its values; the values stay stored in each firm.
    def destroy
      field = @category.fields.find(params[:id])
      audited("category_field.destroy") { field.destroy! }
      redirect_to edit_admin_category_path(@category), notice: "تم حذف الحقل."
    end

    private

    def set_category
      @category = Category.find(params[:category_id])
    end

    # Select options come in as one comma-separated line.
    def field_params
      permitted = params.require(:category_field).permit(:key, :label, :kind, :required, :position, :options)
      permitted[:options] = permitted[:options].to_s.split(/[,،]/).map(&:strip).compact_blank
      permitted
    end
  end
end
