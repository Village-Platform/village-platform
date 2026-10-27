module Media
  # Checks an uploaded blob against its profile. The content type is sniffed from the file's own
  # bytes (the client's header can say anything), the size comes from storage, and a video's
  # duration is read from its header. Raises Media::InvalidFile; returns metadata to store.
  class Validate
    SNIFF_BYTES = 4096

    def self.call(blob:, profile:, max_duration_s: nil) = new(blob:, profile:, max_duration_s:).call

    def initialize(blob:, profile:, max_duration_s:)
      @blob = blob
      @profile = profile
      @max_duration_s = [ profile.max_duration_s, max_duration_s ].compact.min
    end

    def call
      raise InvalidFile.new("file_too_large", size: human_size) if @blob.byte_size > @profile.max_bytes
      raise InvalidFile.new("invalid_media_type", types: @profile.content_types.join(", ")) unless allowed_type?

      @profile.video? ? video_metadata : {}
    end

    private

    def allowed_type?
      head = @blob.download_chunk(0...[ SNIFF_BYTES, @blob.byte_size ].min)
      sniffed = Marcel::MimeType.for(StringIO.new(head))
      sniffed = "video/mp4" if sniffed == "video/x-m4v" # same container; some encoders brand it M4V
      @profile.content_types.include?(sniffed)
    end

    def video_metadata
      duration = Mp4Probe.duration(@blob)
      raise InvalidFile.new("invalid_media_type", types: @profile.content_types.join(", ")) unless duration
      if @max_duration_s && duration > @max_duration_s + 0.5 # encoders round the last frame
        raise InvalidFile.new("media_too_long", seconds: @max_duration_s)
      end

      { duration_s: duration.round }
    end

    def human_size
      ActiveSupport::NumberHelper.number_to_human_size(@profile.max_bytes, locale: :en)
    end
  end
end
