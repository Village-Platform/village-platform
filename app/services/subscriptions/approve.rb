module Subscriptions
  # Approves a pending subscription after the super admin has verified the transfer.
  # Renewals stack: if the owner still has time left, the new period starts when the old one ends.
  class Approve
    def self.call(subscription:, reviewer:) = new(subscription:, reviewer:).call

    def initialize(subscription:, reviewer:)
      @subscription = subscription
      @reviewer = reviewer
    end

    def call
      Subscription.transaction do
        user = @subscription.user
        user.lock! # serialize approvals for the same owner
        @subscription.lock!
        raise ReviewError, "Subscription is not pending" unless @subscription.pending?

        now = Time.current
        starts_at = [ now, user.subscriptions.active.maximum(:ends_at) ].compact.max

        @subscription.update!(
          status: :active,
          starts_at:,
          ends_at: starts_at + @subscription.subscription_plan.duration_days.days,
          reviewed_by: @reviewer,
          reviewed_at: now
        )
        user.update!(role: :firm_admin) if user.user?
      end

      @subscription
    end
  end
end
