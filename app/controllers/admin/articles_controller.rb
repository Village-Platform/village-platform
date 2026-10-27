module Admin
  class ArticlesController < BaseController
    before_action :set_article, only: %i[edit update destroy]

    def index
      scope = Article.includes(:author).order(Arel.sql("published_at DESC NULLS FIRST"), id: :desc)
      scope = scope.where(kind: params[:kind]) if Article.kinds.key?(params[:kind])
      scope = scope.where("articles.title ILIKE ?", like(params[:q])) if params[:q].present?
      @articles, @meta = paginate(scope)
    end

    def new
      @article = Article.new(kind: :news, published_at: Time.current)
    end

    def create
      @article = current_admin.articles.build(article_params)
      if audited("article.create", @article) { @article.save }
        redirect_to admin_articles_path, notice: "تم حفظ الخبر."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if audited("article.update", @article) { @article.update(article_params) }
        redirect_to admin_articles_path, notice: "تم حفظ التعديلات."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      destroy_and_redirect(@article, admin_articles_path)
    end

    private

    def set_article
      @article = Article.find(params[:id])
    end

    def article_params
      params.require(:article).permit(:title, :body, :kind, :published_at)
    end
  end
end
