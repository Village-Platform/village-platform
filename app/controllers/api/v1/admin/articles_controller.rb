module Api
  module V1
    module Admin
      # Super admin review of subscribers' articles.
      class ArticlesController < BaseController
        before_action :authenticate_user!
        before_action :set_article, only: %i[approve reject]

        # GET /api/v1/admin/articles?review_state=pending
        def index
          authorize Article, :review?
          scope = Article.includes(:author, cover_image_attachment: :blob).order(:created_at, :id)
          scope = scope.where(review_state: params[:review_state]) if Article.review_states.key?(params[:review_state])

          records, meta = paginate(scope)
          render json: { data: records.map { ArticleSerializer.render(_1, include_review: true) }, meta: }
        end

        # PATCH /api/v1/admin/articles/:id/approve
        def approve
          render_review(Articles::Review.approve(article: @article, reviewer: current_user))
        end

        # PATCH /api/v1/admin/articles/:id/reject  { "reason": "..." }
        def reject
          reason = params.require(:reason)
          render_review(Articles::Review.reject(article: @article, reviewer: current_user, reason:))
        end

        private

        def set_article
          @article = Article.find(params[:id])
          authorize @article, :review?
        end

        def render_review(article)
          render json: { data: ArticleSerializer.render(article, include_review: true) }
        end
      end
    end
  end
end
