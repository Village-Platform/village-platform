module Subscriptions
  class Reject
    def self.call(subscription:, reviewer:, reason:) = new(subscription:, reviewer:, reason:).call

    def initialize(subscription:, reviewer:, reason:)
      @subscription = subscription
      @reviewer = reviewer
      @reason = reason
    end

    def call
      @subscription.with_lock do
        raise ReviewError, "Subscription is not pending" unless @subscription.pending?

        @subscription.update!(
          status: :rejected,
          rejection_reason: @reason,
          reviewed_by: @reviewer,
          reviewed_at: Time.current
        )
      end

      record_metrics
      notify_owner
      @subscription
    end

    private

    def record_metrics
      Observability::Metrics.increment(:subscriptions_reviewed, outcome: "rejected")
      Observability::Metrics.record(:subscription_review_wait, @subscription.reviewed_at - @subscription.created_at, outcome: "rejected")
    end

    def notify_owner
      Notifier.notify(
        user: @subscription.user,
        kind: :subscription_rejected,
        dedupe_key: "subscription:#{@subscription.id}:rejected",
        data: { subscription_id: @subscription.id },
        reason: @reason
      )
    rescue StandardError => e
      Rails.logger.error("[Subscriptions::Reject] notification failed subscription_id=#{@subscription.id} #{e.class}: #{e.message}")
    end
  end
end
