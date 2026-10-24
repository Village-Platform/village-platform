class ArticleSerializer
  # Expects :author to be preloaded on collections.
  def self.render(article)
    {
      id: article.id,
      title: article.title,
      body: article.body,
      kind: article.kind,
      published_at: article.published_at,
      author: { id: article.author.id, name: article.author.name }
    }
  end
end
