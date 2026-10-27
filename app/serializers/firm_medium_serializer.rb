class FirmMediumSerializer
  THUMBNAIL = { resize_to_limit: [ 480, 480 ], format: :webp }.freeze

  # Expects the file attachment and blob to be preloaded on collections.
  # URLs are relative to the API host and redirect to the stored file (range requests work for
  # video seeking once media lives in object storage).
  def self.render(medium)
    helpers = Rails.application.routes.url_helpers
    {
      id: medium.id,
      kind: medium.kind,
      caption: medium.caption,
      position: medium.position,
      duration_s: medium.duration_s,
      content_type: medium.file.content_type,
      byte_size: medium.file.byte_size,
      url: helpers.rails_blob_path(medium.file, only_path: true),
      thumbnail_url: (helpers.rails_representation_path(medium.file.variant(THUMBNAIL), only_path: true) if medium.image?)
    }
  end
end
