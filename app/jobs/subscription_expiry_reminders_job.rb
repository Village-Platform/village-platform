# Run once a day (cron / scheduler): bin/rails notifications:subscription_reminders
#
# - 7 days and 1 day before expiry -> "subscription_expiring"
# - after expiry (looks back 3 days in case a run was missed) -> "subscription_expired"
# Owners who already renewed (stacked subscription) are skipped.
# Idempotent: every reminder has a dedupe_key, so running it twice sends nothing new.
class SubscriptionExpiryRemindersJob < ApplicationJob
  queue_as :default

  REMINDER_WINDOWS = [ 7, 1 ].freeze # days before expiry
  EXPIRED_LOOKBACK = 3.days

  # The success count feeds the "reminders did not run" alert (deploy/observability).
  def perform
    sent = send_reminders
    Observability::Metrics.increment(:reminder_runs, result: "success")
    Observability::Metrics.increment(:reminders_sent, sent)
    sent
  rescue StandardError
    Observability::Metrics.increment(:reminder_runs, result: "failure")
    raise
  end

  private

  def send_reminders
    now = Time.current
    sent = 0

    Subscription.current.where(ends_at: ..(now + REMINDER_WINDOWS.max.days))
                .includes(:user, :subscription_plan).find_each do |subscription|
      next if subscription.renewed?

      days_left = subscription.days_left
      window = REMINDER_WINDOWS.select { |w| days_left <= w }.min
      sent += 1 if Notifier.notify(
        user: subscription.user,
        kind: :subscription_expiring,
        dedupe_key: "subscription:#{subscription.id}:expiring:#{window}",
        data: { subscription_id: subscription.id, days_left: },
        destination: Notifications::Destination.new(screen: "subscription", id: subscription.id),
        plan: subscription.subscription_plan.name,
        days: days_left
      )
    end

    Subscription.active.where(ends_at: (now - EXPIRED_LOOKBACK)..now)
                .includes(:user, :subscription_plan).find_each do |subscription|
      next if subscription.renewed?

      sent += 1 if Notifier.notify(
        user: subscription.user,
        kind: :subscription_expired,
        dedupe_key: "subscription:#{subscription.id}:expired",
        data: { subscription_id: subscription.id },
        destination: Notifications::Destination.new(screen: "subscription", id: subscription.id),
        plan: subscription.subscription_plan.name
      )
    end

    Rails.logger.info("[SubscriptionExpiryRemindersJob] notifications_sent=#{sent}")
    sent
  end
end
