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

      @subscription
    end
  end
end
