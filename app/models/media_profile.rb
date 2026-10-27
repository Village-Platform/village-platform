# The single definition of "a valid, small file" for each kind of attachment. Published at
# GET /api/v1/media_profiles so the Android app compresses to these targets; the server checks
# every upload against them anyway, because any HTTP client can call the API.
MediaProfile = Data.define(:name, :kind, :content_types, :max_bytes, :max_edge_px, :max_duration_s, :target,
                           :object_storage)

class MediaProfile
  IMAGE_TYPES = %w[image/png image/jpeg image/webp].freeze

  # target[:quality] is the client's encoder setting; target[:lossless] means never re-encode lossy.
  ALL = [
    new(name: "category_icon", kind: :image, content_types: IMAGE_TYPES, max_bytes: 512.kilobytes,
        max_edge_px: 512, max_duration_s: nil, target: { format: "image/webp", strategy: "smallest_visually_lossless", quality: 90 },
        object_storage: false),
    new(name: "firm_image", kind: :image, content_types: %w[image/jpeg image/webp image/png], max_bytes: 1536.kilobytes,
        max_edge_px: 2048, max_duration_s: nil, target: { format: "image/webp", quality: 82 },
        object_storage: false),
    new(name: "firm_video", kind: :video, content_types: %w[video/mp4], max_bytes: 40.megabytes,
        max_edge_px: 1280, max_duration_s: 60,
        target: { format: "video/mp4", video_codec: "h264", video_bitrate_kbps: 2500, audio_codec: "aac",
                  audio_bitrate_kbps: 96 },
        object_storage: true),
    new(name: "article_image", kind: :image, content_types: %w[image/jpeg image/webp image/png], max_bytes: 1536.kilobytes,
        max_edge_px: 2048, max_duration_s: nil, target: { format: "image/webp", quality: 82 },
        object_storage: false),
    # Evidence of a transfer: lossy artefacts on digits could cause a wrong review, so it stays lossless.
    new(name: "payment_screenshot", kind: :image, content_types: IMAGE_TYPES, max_bytes: 4.megabytes,
        max_edge_px: 2400, max_duration_s: nil, target: { format: "image/png", lossless: true },
        object_storage: false)
  ].index_by(&:name).freeze

  def self.fetch(name)
    ALL.fetch(name.to_s) { raise ArgumentError, "Unknown media profile: #{name}" }
  end

  def self.all = ALL.values

  # Active Storage service for media that must not live in PostgreSQL (video). Nil means the
  # app's default service.
  def self.object_storage_service
    ENV["MEDIA_STORAGE_SERVICE"].presence&.to_sym
  end

  def image? = kind == :image
  def video? = kind == :video

  # Server-side re-encoding only ever applies to lossy-targeted images.
  def optimize? = image? && !target[:lossless]

  def as_json(*)
    { name:, kind:, content_types:, max_bytes:, max_edge_px:, max_duration_s:, target: }
  end
end
