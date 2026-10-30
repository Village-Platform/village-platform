module Admin
  class ArticlesController < BaseController
    before_action :set_article, only: %i[show edit update destroy restore destroy_fully]

    def index
      scope = case params[:deleted]
      when "only" then Article.only_deleted
      when "all" then Article.with_deleted
      else Article.all
      end

      scope = scope.includes(:author).order(Arel.sql("published_at DESC NULLS FIRST"), id: :desc)
      scope = scope.where(kind: params[:kind]) if Article.kinds.key?(params[:kind])
      scope = scope.where("articles.title ILIKE ?", like(params[:q])) if params[:q].present?

      @deleted_count = Article.only_deleted.count
      @articles, @meta = paginate(filter(scope))
    end

    def show; end

    def new
      @article = Article.new(kind: :news, published_at: Time.current)
    end

    def create
      @article = current_admin.articles.build(article_params)
      if @article.save
        redirect_to admin_articles_path, notice: "تم حفظ المقال."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @article.update(article_params)
        redirect_to admin_articles_path, notice: "تم حفظ التعديلات."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      destroy_and_redirect(@article, admin_articles_path)
    end

    def restore
      restore_and_redirect(@article, admin_article_path(@article))
    end

    def destroy_fully
      destroy_fully_and_redirect(@article, admin_articles_path)
    end

    private

    def set_article
      @article = Article.with_deleted.find(params[:id])
    end

    def article_params
      params.require(:article).permit(:title, :body, :kind, :published_at)
    end
  end
end
