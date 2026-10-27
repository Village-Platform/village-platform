module FirmMedia
  # Adds an image or video to a firm's gallery within the uploader's plan limit.
  #
  # The file is ingested (validated, optimized) first, outside the transaction, because it does
  # I/O. The slot is then taken under a lock on the firm row, so two parallel uploads cannot both
  # take the last free slot; the loser's blob is purged.
  class Add
    def self.call(**) = new(**).call

    def initialize(firm:, uploader:, kind:, caption: nil, file: nil, signed_blob_id: nil)
      @firm = firm
      @uploader = uploader
      @kind = kind.to_s
      @caption = caption
      @file = file
      @signed_blob_id = signed_blob_id
    end

    def call
      raise Media::InvalidFile.new("bad_request", param: "kind") unless FirmMedium.kinds.key?(@kind)

      entitlements = @uploader.entitlements
      limit = FirmMedium.limit_for(@kind)
      raise Media::LimitReached unless entitlements.within?(limit, @firm.media.where(kind: @kind).count)

      result = Media::Ingest.call(profile: FirmMedium.new(kind: @kind).profile, uploader: @uploader,
                                  file: @file, signed_blob_id: @signed_blob_id,
                                  max_duration_s: entitlements.max_video_seconds)
      create_medium(result, entitlements.public_send(limit))
    end

    private

    def create_medium(result, limit)
      FirmMedium.transaction do
        @firm.lock!
        media = @firm.media.where(kind: @kind)
        raise Media::LimitReached if limit && media.count >= limit

        medium = @firm.media.create!(kind: @kind, caption: @caption, duration_s: result.metadata[:duration_s],
                                     position: (@firm.media.maximum(:position) || -1) + 1, file: result.blob)
        Audit.record(actor: @uploader, action: "firm_medium.create", subject: medium)
        medium
      end
    rescue Media::LimitReached, ActiveRecord::RecordInvalid
      result.blob.purge
      raise
    end
  end
end
