class ArticleSerializer
  # Expects :author (and the cover attachment) to be preloaded on collections.
  # include_review adds the rejection reason, which only the author and admins should see.
  def self.render(article, include_review: false)
    data = {
      id: article.id,
      title: article.title,
      body: article.body,
      kind: article.kind,
      published_at: article.published_at,
      author: { id: article.author.id, name: article.author.name },
      firm_id: article.firm_id,
      review_state: article.review_state,
      cover_image_url: (Rails.application.routes.url_helpers.rails_blob_path(article.cover_image, only_path: true) if article.cover_image.attached?)
    }
    data[:rejection_reason] = article.rejection_reason if include_review
    data
  end
end
