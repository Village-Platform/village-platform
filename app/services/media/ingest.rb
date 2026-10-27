module Media
  # Turns an upload into a blob that meets its profile, ready to attach.
  #
  # The source is either a multipart file or the signed id returned by
  # POST /api/v1/direct_uploads (the bytes then went straight to object storage).
  # A direct-uploaded blob is only accepted from the user who requested it and for the profile it
  # was requested for. A blob that fails validation, or that Optimize replaced, is purged.
  class Ingest
    Result = Data.define(:blob, :metadata)

    def self.call(**) = new(**).call

    def initialize(profile:, uploader:, file: nil, signed_blob_id: nil, max_duration_s: nil)
      @profile = profile
      @uploader = uploader
      @file = file
      @signed_blob_id = signed_blob_id
      @max_duration_s = max_duration_s
    end

    def call
      blob = source_blob
      begin
        metadata = Validate.call(blob:, profile: @profile, max_duration_s: @max_duration_s)
        optimized = Optimize.call(blob:, profile: @profile)
      rescue InvalidFile
        blob.purge
        raise
      end
      blob.purge if optimized != blob
      Result.new(blob: optimized, metadata:)
    end

    private

    def source_blob
      return uploaded_blob if @file.respond_to?(:read)
      return direct_uploaded_blob if @signed_blob_id.present?

      raise InvalidFile.new("bad_request", param: "file")
    end

    def uploaded_blob
      ActiveStorage::Blob.create_and_upload!(
        io: @file, filename: @file.original_filename.presence || "upload", content_type: @file.content_type,
        service_name: Media.service_name_for(@profile), metadata: { "profile" => @profile.name }
      )
    end

    def direct_uploaded_blob
      blob = ActiveStorage::Blob.find_signed(@signed_blob_id)
      unless blob && blob.metadata["profile"] == @profile.name && blob.metadata["uploader_id"] == @uploader.id &&
             blob.attachments.none? && blob.service.exist?(blob.key)
        raise InvalidFile.new("invalid_blob")
      end

      blob
    end
  end
end
