# Daily: removes blobs nobody attached — abandoned direct uploads and failed form submissions.
# A day of grace keeps an upload that is still being attached safe. Idempotent.
class PurgeUnattachedBlobsJob < ApplicationJob
  queue_as :default

  GRACE = 1.day

  def perform
    purged = 0
    ActiveStorage::Blob.unattached.where(created_at: ..GRACE.ago).find_each do |blob|
      blob.purge
      purged += 1
    end
    Rails.logger.info("[PurgeUnattachedBlobsJob] blobs_purged=#{purged}")
    purged
  end
end
