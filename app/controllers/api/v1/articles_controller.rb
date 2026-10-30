module Api
  module V1
    class ArticlesController < BaseController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_article, only: %i[show update destroy]

      # GET /api/v1/articles?kind=news
      def index
        scope = policy_scope(Article).includes(:author).latest_first
        scope = scope.where(kind: params[:kind]) if Article.kinds.key?(params[:kind])

        records, meta = paginate(filter(scope))
        render_collection(records, meta, ArticleSerializer)
      end

      def show
        authorize @article
        render_record(@article, ArticleSerializer)
      end

      def create
        authorize Article
        article = current_user.articles.create!(permitted_attributes(Article))
        render_record(article, ArticleSerializer, status: :created)
      end

      def update
        authorize @article
        @article.update!(permitted_attributes(@article))
        render_record(@article, ArticleSerializer)
      end

      def destroy
        authorize @article
        @article.destroy!
        head :no_content
      end

      private

      def set_article
        @article = policy_scope(Article).find(params[:id])
      end
    end
  end
end
