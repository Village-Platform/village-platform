module Campaigns
  # Saves a campaign as scheduled and queues its delivery. Also reschedules: call it again with a
  # new scheduled_at, and the job queued for the old time finds a mismatch and does nothing.
  class Schedule
    def self.call(campaign:)
      campaign.scheduled_at ||= Time.current
      campaign.status = :scheduled

      NotificationCampaign.transaction do
        campaign.save!
        DeliverCampaignJob.set(wait_until: campaign.scheduled_at)
                          .perform_later(campaign.id, campaign.scheduled_at.iso8601(6))
      end
      campaign
    end
  end
end
