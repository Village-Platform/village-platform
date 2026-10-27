module Media
  # Re-encodes an image blob to its profile's target: longest edge capped, metadata (EXIF GPS!)
  # removed, encoded as WEBP. Returns the blob to attach — the same one when it already meets the
  # target, so a well-behaved client's upload is never re-encoded (each lossy pass loses detail).
  class Optimize
    # Average CIEDE2000 distance below which people cannot tell two images apart.
    VISUALLY_LOSSLESS_DE = 1.0
    METADATA_PREFIXES = %w[exif- xmp- iptc- icc-profile].freeze

    def self.call(blob:, profile:) = new(blob:, profile:).call

    def initialize(blob:, profile:)
      @blob = blob
      @profile = profile
    end

    def call
      return @blob unless @profile.optimize?
      return @blob if @blob.metadata["optimized"]

      @blob.open do |file|
        image = Vips::Image.new_from_file(file.path).autorot
        return @blob if meets_target?(image)

        resized = resize(image)
        data = smallest_visually_lossless? ? smallest_visually_lossless(resized) : lossy(resized)
        # A clean original that the target format cannot beat (a tiny PNG) is kept as it is.
        return @blob if data.bytesize >= @blob.byte_size && clean?(image)

        upload(data)
      end
    rescue Vips::Error => e
      raise InvalidFile.new("invalid_media_type", types: @profile.content_types.join(", ")), cause: e
    end

    private

    def meets_target?(image)
      @blob.content_type == @profile.target[:format] && clean?(image)
    end

    # Within the size limit and carrying no metadata (EXIF can hold the phone's GPS position).
    def clean?(image)
      [ image.width, image.height ].max <= @profile.max_edge_px &&
        image.get_fields.none? { |field| field.start_with?(*METADATA_PREFIXES) }
    end

    def resize(image)
      longest = [ image.width, image.height ].max
      longest > @profile.max_edge_px ? image.resize(@profile.max_edge_px.to_f / longest) : image
    end

    def lossy(image)
      image.webpsave_buffer(Q: @profile.target[:quality], strip: true)
    end

    def smallest_visually_lossless?
      @profile.target[:strategy] == "smallest_visually_lossless"
    end

    # Flat colours and transparency (icons) usually win lossless; photos win lossy. Lossy is kept
    # only when it is both smaller and indistinguishable from the source.
    def smallest_visually_lossless(image)
      lossless = image.webpsave_buffer(lossless: true, strip: true)
      lossy = lossy(image)
      return lossless if lossy.bytesize >= lossless.bytesize

      distance(image, Vips::Image.new_from_buffer(lossy, "")) < VISUALLY_LOSSLESS_DE ? lossy : lossless
    end

    def distance(original, encoded)
      lab(original).dE00(lab(encoded)).avg
    end

    def lab(image)
      image = image.flatten(background: [ 255, 255, 255 ]) if image.has_alpha?
      image.colourspace(:lab)
    end

    def upload(data)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(data),
        filename: "#{@blob.filename.base}.webp",
        content_type: "image/webp",
        service_name: @blob.service_name,
        metadata: { "optimized" => true },
        identify: false
      )
    end
  end
end
