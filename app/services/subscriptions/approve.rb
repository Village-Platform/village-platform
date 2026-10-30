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

      record_metrics
      notify_owner
      @subscription
    end

    private

    # After the commit, like the notification: telemetry never holds the locks or undoes an approval.
    def record_metrics
      Observability::Metrics.increment(:subscriptions_reviewed, outcome: "approved")
      Observability::Metrics.record(:subscription_review_wait, @subscription.reviewed_at - @subscription.created_at, outcome: "approved")
    end

    # Outside the transaction: a failed notification must never undo an approval.
    def notify_owner
      Notifier.notify(
        user: @subscription.user,
        kind: :subscription_approved,
        dedupe_key: "subscription:#{@subscription.id}:approved",
        data: { subscription_id: @subscription.id },
        destination: Notifications::Destination.new(screen: "subscription", id: @subscription.id),
        plan: @subscription.subscription_plan.name,
        ends_at: I18n.l(@subscription.ends_at.to_date, locale: I18n.default_locale)
      )
    rescue StandardError => e
      Rails.logger.error("[Subscriptions::Approve] notification failed subscription_id=#{@subscription.id} #{e.class}: #{e.message}")
    end
  end
end
