module Articles
  # A subscriber writes an article: it waits in `pending` until a super admin reviews it.
  # The monthly quota is checked under a lock on the author row (as Subscriptions::Approve
  # does), so two parallel submissions cannot both take the last slot.
  class Submit
    def self.call(**) = new(**).call

    def initialize(author:, attributes:, cover_image: nil, cover_signed_blob_id: nil)
      @author = author
      @attributes = attributes
      @cover_image = cover_image
      @cover_signed_blob_id = cover_signed_blob_id
    end

    def call
      cover = ingest_cover
      Article.transaction do
        @author.lock!
        raise Media::LimitReached unless @author.entitlements.within?(:max_articles_per_month, @author.articles_this_month)

        article = @author.articles.create!(@attributes.merge(review_state: :pending, published_at: nil, cover_image: cover))
        Audit.record(actor: @author, action: "article.create", subject: article)
        article
      end
    rescue Media::LimitReached, ActiveRecord::RecordInvalid
      cover&.purge
      raise
    end

    private

    def ingest_cover
      return if @cover_image.blank? && @cover_signed_blob_id.blank?

      Media::Ingest.call(profile: MediaProfile.fetch(:article_image), uploader: @author,
                         file: @cover_image.presence, signed_blob_id: @cover_signed_blob_id).blob
    end
  end
end
