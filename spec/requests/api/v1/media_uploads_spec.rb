require "rails_helper"

RSpec.describe "Media profiles and direct uploads", type: :request do
  def direct_upload_params(profile:, byte_size: 1000, content_type: "image/webp")
    { profile:, blob: { filename: "x.webp", byte_size:, checksum: Base64.strict_encode64("0" * 16), content_type: } }
  end

  describe "GET /api/v1/media_profiles" do
    it "publishes every profile's targets, publicly cacheable" do
      get "/api/v1/media_profiles"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to include("public")
      firm_image = json["data"].find { _1["name"] == "firm_image" }
      expect(firm_image).to include("max_bytes" => 1536.kilobytes, "max_edge_px" => 2048,
                                    "target" => { "format" => "image/webp", "quality" => 82 })
      expect(json["data"].map { _1["name"] }).to include("firm_video", "category_icon", "payment_screenshot")
    end
  end

  describe "POST /api/v1/direct_uploads" do
    let(:subscriber) { create(:user, :subscribed) }

    it "returns a signed id and an upload URL for an entitled user" do
      post "/api/v1/direct_uploads", params: direct_upload_params(profile: "firm_image"), headers: auth_headers(subscriber)

      expect(response).to have_http_status(:created)
      expect(json["data"]["signed_id"]).to be_present
      expect(json["data"]["direct_upload"]["url"]).to be_present
      blob = ActiveStorage::Blob.find_signed(json["data"]["signed_id"])
      expect(blob.metadata).to include("profile" => "firm_image", "uploader_id" => subscriber.id)
    end

    it "refuses a declared size or type outside the profile before signing anything" do
      expect {
        post "/api/v1/direct_uploads", params: direct_upload_params(profile: "firm_image", byte_size: 5.megabytes),
                                       headers: auth_headers(subscriber)
      }.not_to change(ActiveStorage::Blob, :count)
      expect(json["error"]["code"]).to eq("file_too_large")

      post "/api/v1/direct_uploads", params: direct_upload_params(profile: "firm_image", content_type: "image/gif"),
                                     headers: auth_headers(subscriber)
      expect(json["error"]["code"]).to eq("invalid_media_type")
    end

    it "refuses users whose plan does not include the media kind" do
      post "/api/v1/direct_uploads", params: direct_upload_params(profile: "firm_video", content_type: "video/mp4"),
                                     headers: auth_headers(subscriber) # default plan: 0 videos
      expect(response).to have_http_status(:forbidden)

      post "/api/v1/direct_uploads", params: direct_upload_params(profile: "category_icon"), headers: auth_headers(subscriber)
      expect(response).to have_http_status(:forbidden)

      post "/api/v1/direct_uploads", params: direct_upload_params(profile: "firm_image")
      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses video when the only storage is PostgreSQL" do
      admin = create(:user, :super_admin)
      allow(Media).to receive(:database_service?).and_return(true)

      post "/api/v1/direct_uploads", params: direct_upload_params(profile: "firm_video", content_type: "video/mp4"),
                                     headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("media_storage_unavailable")
    end
  end

  describe "GET /internal/cron/purge_unattached_blobs" do
    around do |example|
      previous = ENV["CRON_SECRET"]
      ENV["CRON_SECRET"] = "test-cron-secret"
      example.run
    ensure
      ENV["CRON_SECRET"] = previous
    end

    it "runs the purge with the cron secret" do
      allow(PurgeUnattachedBlobsJob).to receive(:perform_now).and_return(3)

      get "/internal/cron/purge_unattached_blobs", headers: { "Authorization" => "Bearer test-cron-secret" }

      expect(response.parsed_body).to eq("purged" => 3)
    end
  end
end
