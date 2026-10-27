module Articles
  # Approves or rejects a subscriber's pending article. Used by the dashboard and the API, so
  # both front doors publish the same way. The author is notified outside the transaction: a
  # failed notification must never undo a review.
  class Review
    def self.approve(article:, reviewer:) = new(article:, reviewer:).approve
    def self.reject(article:, reviewer:, reason:) = new(article:, reviewer:).reject(reason)

    def initialize(article:, reviewer:)
      @article = article
      @reviewer = reviewer
    end

    def approve
      review(:approve, review_state: :approved, published_at: Time.current, rejection_reason: nil)
      notify(:article_approved)
    end

    def reject(reason)
      review(:reject, review_state: :rejected, rejection_reason: reason)
      notify(:article_rejected, reason:)
    end

    private

    def review(verb, attributes)
      Audit.operation("article.#{verb}", actor: @reviewer) do
        @article.with_lock do
          raise Subscriptions::ReviewError, "Article is not pending" unless @article.pending?

          @article.update!(attributes.merge(reviewed_by: @reviewer, reviewed_at: Time.current))
        end
      end
    end

    def notify(kind, **interpolations)
      Notifier.notify(
        user: @article.author, kind:,
        dedupe_key: "article:#{@article.id}:#{kind}:#{@article.reviewed_at.to_i}",
        data: { article_id: @article.id }, title: @article.title, **interpolations
      )
      @article
    rescue StandardError => e
      Rails.logger.error("[Articles::Review] notification failed article_id=#{@article.id} #{e.class}: #{e.message}")
      @article
    end
  end
end
