module Categories
  # Shrinks a category's icon to the category_icon profile (≤512px, the smaller of lossless and
  # visually lossless WEBP). Called explicitly after every icon change rather than from a model
  # callback, so seeds, the API, the dashboard and the backfill task all take the same path.
  # Idempotent: an icon already optimized is skipped. Returns true when it replaced the image.
  class OptimizeIcon
    def self.call(category)
      return false unless category.icon_image.attached?

      blob = category.icon_image.blob
      return false if blob.metadata["optimized"]

      optimized = Media::Optimize.call(blob:, profile: MediaProfile.fetch(:category_icon))
      if optimized == blob
        blob.update!(metadata: blob.metadata.merge("optimized" => true))
        false
      else
        category.icon_image.attach(optimized) # the replaced blob is purged by Active Storage
        true
      end
    rescue Media::InvalidFile => e
      # The upload already passed the model's type and size checks; keep it rather than fail.
      Rails.logger.warn("[Categories::OptimizeIcon] category_id=#{category.id} kept original: #{e.code}")
      false
    end
  end
end
