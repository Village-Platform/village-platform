module Api
  module V1
    class CategoriesController < BaseController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_category, only: %i[show update destroy]

      def index
        records, meta = paginate(policy_scope(Category).ordered)
        render_collection(records, meta, CategorySerializer)
      end

      def show
        authorize @category
        render_record(@category, CategorySerializer)
      end

      def create
        authorize Category
        category = Category.create!(permitted_attributes(Category))
        render_record(category, CategorySerializer, status: :created)
      end

      def update
        authorize @category
        @category.update!(permitted_attributes(@category))
        render_record(@category, CategorySerializer)
      end

      def destroy
        authorize @category
        if @category.destroy
          head :no_content
        else
          render_error(:unprocessable_content, "cannot_delete", details: @category.errors.to_hash(true))
        end
      end

      private

      def set_category
        @category = policy_scope(Category).find(params[:id])
      end
    end
  end
end
