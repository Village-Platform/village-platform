require "rails_helper"

RSpec.describe "Media pipeline" do
  def blob_for(name, content_type: nil)
    path = file_fixture(name)
    ActiveStorage::Blob.create_and_upload!(io: path.open("rb"), filename: name, content_type:)
  end

  def vips(blob)
    blob.open { |file| Vips::Image.new_from_file(file.path) }
  end

  describe Media::Validate do
    it "sniffs the type from the bytes, not the declared content type" do
      text_as_png = blob_for("receipt.txt", content_type: "image/png")

      expect { described_class.call(blob: text_as_png, profile: MediaProfile.fetch(:firm_image)) }
        .to raise_error(Media::InvalidFile) { |e| expect(e.code).to eq("invalid_media_type") }
    end

    it "rejects a file above the profile's size" do
      blob = blob_for("photo_with_gps.jpg")
      profile = MediaProfile.fetch(:firm_image).with(max_bytes: 1.kilobyte)

      expect { described_class.call(blob:, profile:) }
        .to raise_error(Media::InvalidFile) { |e| expect(e.code).to eq("file_too_large") }
    end

    it "reads a video's duration whether the movie header is at the start or the end" do
      profile = MediaProfile.fetch(:firm_video)

      expect(described_class.call(blob: blob_for("clip_3s.mp4"), profile:)).to eq(duration_s: 3)
      expect(described_class.call(blob: blob_for("clip_moov_at_end.mp4"), profile:)).to eq(duration_s: 3)
    end

    it "applies the lower of the profile's and the plan's duration limit" do
      expect { described_class.call(blob: blob_for("clip_3s.mp4"), profile: MediaProfile.fetch(:firm_video), max_duration_s: 2) }
        .to raise_error(Media::InvalidFile) { |e| expect(e.code).to eq("media_too_long") }
    end
  end

  describe Media::Optimize do
    it "resizes a phone photo, strips its GPS metadata and encodes WEBP" do
      original = blob_for("photo_with_gps.jpg")
      expect(vips(original).get_fields).to include("exif-data")

      optimized = described_class.call(blob: original, profile: MediaProfile.fetch(:firm_image))
      image = vips(optimized)

      expect(optimized.content_type).to eq("image/webp")
      expect([ image.width, image.height ].max).to eq(2048)
      expect(image.get_fields.grep(/exif|xmp|iptc/)).to be_empty
      expect(optimized.byte_size).to be < original.byte_size
    end

    it "leaves an upload that already meets the target untouched" do
      optimized = described_class.call(blob: blob_for("photo_with_gps.jpg"), profile: MediaProfile.fetch(:firm_image))

      expect(described_class.call(blob: optimized, profile: MediaProfile.fetch(:firm_image))).to eq(optimized)
    end

    it "never re-encodes a lossless profile such as payment screenshots" do
      blob = blob_for("photo_with_gps.jpg")

      expect(described_class.call(blob:, profile: MediaProfile.fetch(:payment_screenshot))).to eq(blob)
    end

    it "picks the smaller visually lossless encoding for an icon and caps its edge" do
      original = blob_for("icon_large.png")
      optimized = described_class.call(blob: original, profile: MediaProfile.fetch(:category_icon))
      image = vips(optimized)

      expect(optimized.content_type).to eq("image/webp")
      expect([ image.width, image.height ].max).to eq(512)
      expect(image.has_alpha?).to be(true)
      expect(optimized.byte_size).to be < original.byte_size
    end
  end

  describe PurgeUnattachedBlobsJob do
    it "purges unattached blobs older than a day and keeps recent or attached ones" do
      old = blob_for("receipt.png")
      old.update_columns(created_at: 2.days.ago)
      recent = blob_for("receipt.png")
      category = create(:category)
      category.icon_image.attach(blob_for("receipt.png"))
      category.icon_image.blob.update_columns(created_at: 2.days.ago)

      expect(described_class.perform_now).to eq(1)
      expect(ActiveStorage::Blob.exists?(old.id)).to be(false)
      expect(ActiveStorage::Blob.exists?(recent.id)).to be(true)
      expect(category.reload.icon_image).to be_attached
    end
  end
end
