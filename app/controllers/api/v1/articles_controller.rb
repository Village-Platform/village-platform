module Api
  module V1
    class ArticlesController < BaseController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_article, only: %i[show update destroy]

      # GET /api/v1/articles?kind=news
      def index
        scope = policy_scope(Article).includes(:author, cover_image_attachment: :blob).latest_first
        scope = scope.where(kind: params[:kind]) if Article.kinds.key?(params[:kind])

        records, meta = paginate(scope)
        render_collection(records, meta, ArticleSerializer)
      end

      # GET /api/v1/me/articles — the author's own articles in every review state.
      def mine
        scope = current_user.articles.includes(:author, cover_image_attachment: :blob).order(created_at: :desc, id: :desc)
        records, meta = paginate(scope)
        render json: { data: records.map { ArticleSerializer.render(_1, include_review: true) }, meta: }
      end

      def show
        authorize @article
        render json: { data: ArticleSerializer.render(@article, include_review: reviewer_or_author?) }
      end

      # Super admins publish directly; subscribers submit for review (multipart cover_image or
      # cover_signed_blob_id for the cover).
      def create
        authorize Article
        attrs = permitted_attributes(Article)
        article =
          if current_user.super_admin?
            current_user.articles.build(attrs).tap { |a| audited("article.create", a) { a.save! } }
          else
            raise Pundit::NotAuthorizedError unless Article::SUBSCRIBER_KINDS.include?(attrs.fetch(:kind, "news").to_s)

            Articles::Submit.call(author: current_user, attributes: attrs, cover_image: params[:cover_image],
                                  cover_signed_blob_id: params[:cover_signed_blob_id])
          end
        render json: { data: ArticleSerializer.render(article, include_review: true) }, status: :created
      end

      # A subscriber's edit goes back to review, so an approved article cannot be swapped for
      # unreviewed text.
      def update
        authorize @article
        attrs = permitted_attributes(@article)
        attrs = attrs.merge(review_state: :pending, published_at: nil, rejection_reason: nil) unless current_user.super_admin?
        audited("article.update", @article) { @article.update!(attrs) }
        render json: { data: ArticleSerializer.render(@article, include_review: true) }
      end

      def destroy
        authorize @article
        audited("article.destroy", @article, changes: Audit.snapshot(@article)) { @article.destroy! }
        head :no_content
      end

      private

      def set_article
        @article = policy_scope(Article).find(params[:id])
      end

      def reviewer_or_author?
        current_user.present? && (current_user.super_admin? || @article.author_id == current_user.id)
      end
    end
  end
end
