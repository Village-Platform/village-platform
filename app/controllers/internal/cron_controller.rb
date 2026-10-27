# Endpoints called by Vercel Cron (see vercel.json).
# Vercel sends "Authorization: Bearer <CRON_SECRET>"; anything else gets 401.
module Internal
  class CronController < ActionController::API
    before_action :authenticate_cron!

    # GET /internal/cron/subscription_reminders  (daily)
    def subscription_reminders
      sent = SubscriptionExpiryRemindersJob.perform_now
      render json: { sent: }
    end

    # GET /internal/cron/purge_unattached_blobs  (daily)
    def purge_unattached_blobs
      render json: { purged: PurgeUnattachedBlobsJob.perform_now }
    end

    private

    def info_for_paper_trail = { source: "cron", request_id: request.request_id }

    def authenticate_cron!
      secret = ENV["CRON_SECRET"].to_s
      given = request.authorization.to_s
      return if secret.present? && ActiveSupport::SecurityUtils.secure_compare(given, "Bearer #{secret}")

      head :unauthorized
    end
  end
end
