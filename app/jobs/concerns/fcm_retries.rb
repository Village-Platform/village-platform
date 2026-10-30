# FCM failures that every push job handles the same way:
# - Retryable (429/5xx): retry, no sooner than FCM's Retry-After, at most 5 attempts.
# - AuthError (401/403): a bad or mismatched key. Retrying cannot help and would hammer Google,
#   so the job stops; the metric feeds the push-failure alert.
module FcmRetries
  extend ActiveSupport::Concern

  MAX_ATTEMPTS = 5

  included do
    rescue_from Fcm::Retryable do |error|
      if executions >= MAX_ATTEMPTS
        fcm_gave_up(error)
        raise error
      end

      record_push("retry")
      retry_job(wait: [ error.retry_after.to_i, 2**executions ].max.seconds)
    end

    rescue_from Fcm::AuthError do |error|
      Rails.logger.error("[#{self.class.name}] FCM rejected our credentials: #{error.message}")
      record_push("auth_error")
    end
  end

  private

  # Hook for jobs that track state (e.g. a campaign's status) when the last retry fails.
  def fcm_gave_up(_error); end

  def record_push(result)
    Observability::Metrics.increment(:push_sent, source: push_source, result:)
  end
end
