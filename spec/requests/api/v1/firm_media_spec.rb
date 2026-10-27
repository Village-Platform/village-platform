require "rails_helper"

RSpec.describe "Firm media gallery", type: :request do
  let(:plan) { create(:subscription_plan, max_images_per_firm: 2, max_videos_per_firm: 1, max_video_seconds: 10) }
  let(:owner) { create(:user, :firm_admin).tap { |u| create(:subscription, :current, user: u, subscription_plan: plan) } }
  let(:firm) { create(:firm, owner:) }

  def add_image(as: owner, fixture: "photo_with_gps.jpg", type: "image/jpeg")
    post "/api/v1/firms/#{firm.id}/media",
         params: { kind: "image", caption: "واجهة المحل", file: fixture_file_upload(fixture, type) },
         headers: auth_headers(as)
  end

  it "lets a subscribed owner add an optimized image and the public list it" do
    add_image

    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("kind" => "image", "caption" => "واجهة المحل", "content_type" => "image/webp")
    expect(json["data"]["thumbnail_url"]).to be_present

    get "/api/v1/firms/#{firm.id}/media"
    expect(json["data"].size).to eq(1)

    get "/api/v1/firms"
    listed = json["data"].find { _1["id"] == firm.id }
    expect(listed["media_count"]).to eq("images" => 1, "videos" => 0)
    expect(listed["cover_image_url"]).to be_present
  end

  it "refuses an image beyond the plan limit and stores nothing for it" do
    2.times { add_image(fixture: "receipt.png", type: "image/png") }

    expect { add_image }.not_to change(ActiveStorage::Blob, :count)
    expect(response).to have_http_status(:forbidden)
    expect(json["error"]["code"]).to eq("media_limit_reached")
  end

  it "accepts a direct-uploaded video within the plan's duration" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("clip_3s.mp4").open, filename: "clip.mp4",
                                                  metadata: { "profile" => "firm_video", "uploader_id" => owner.id })

    post "/api/v1/firms/#{firm.id}/media", params: { kind: "video", signed_blob_id: blob.signed_id },
                                           headers: auth_headers(owner)

    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("kind" => "video", "duration_s" => 3, "thumbnail_url" => nil)
  end

  it "refuses a direct-uploaded blob that belongs to someone else" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("clip_3s.mp4").open, filename: "clip.mp4",
                                                  metadata: { "profile" => "firm_video", "uploader_id" => create(:user).id })

    post "/api/v1/firms/#{firm.id}/media", params: { kind: "video", signed_blob_id: blob.signed_id },
                                           headers: auth_headers(owner)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["error"]["code"]).to eq("invalid_blob")
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true) # not purged: it is not ours
  end

  it "refuses a file whose bytes are not an allowed type" do
    add_image(fixture: "receipt.txt", type: "image/png")

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["error"]["code"]).to eq("invalid_media_type")
  end

  it "refuses owners whose subscription has expired" do
    expired = create(:user, :firm_admin).tap { |u| create(:subscription, :expired, user: u) }
    own_firm = create(:firm, owner: expired)

    post "/api/v1/firms/#{own_firm.id}/media", params: { kind: "image", file: fixture_file_upload("receipt.png", "image/png") },
                                               headers: auth_headers(expired)

    expect(response).to have_http_status(:forbidden)
  end

  it "hides the media of a firm the public cannot see" do
    hidden = create(:firm, :pending, owner:)

    get "/api/v1/firms/#{hidden.id}/media"

    expect(response).to have_http_status(:not_found)
  end

  it "lets only the owner or a super admin edit and delete" do
    add_image
    medium_id = json["data"]["id"]

    patch "/api/v1/firms/#{firm.id}/media/#{medium_id}", params: { medium: { caption: "x" } },
                                                         headers: auth_headers(create(:user, :subscribed))
    expect(response).to have_http_status(:forbidden)

    patch "/api/v1/firms/#{firm.id}/media/#{medium_id}", params: { medium: { caption: "جديد", position: 5 } },
                                                         headers: auth_headers(owner)
    expect(json["data"]).to include("caption" => "جديد", "position" => 5)

    delete "/api/v1/firms/#{firm.id}/media/#{medium_id}", headers: auth_headers(create(:user, :super_admin))
    expect(response).to have_http_status(:no_content)
    expect(PaperTrail::Version.last).to have_attributes(operation: "firm_medium.destroy", event: "destroy")
  end

  it "removes the gallery with the firm" do
    add_image

    expect { delete "/api/v1/firms/#{firm.id}", headers: auth_headers(owner) }.to change(FirmMedium, :count).by(-1)
  end

  describe "dashboard" do
    it "shows the gallery and lets an admin add and remove images" do
      sign_in_admin

      post "/admin/firms/#{firm.id}/media", params: { file: fixture_file_upload("receipt.png", "image/png"), caption: "x" }
      expect(response).to redirect_to("/admin/firms/#{firm.id}")
      medium = firm.media.last

      get "/admin/firms/#{firm.id}"
      expect(response.body).to include("الصور والفيديو")

      delete "/admin/firms/#{firm.id}/media/#{medium.id}"
      expect(FirmMedium.exists?(medium.id)).to be(false)
    end
  end
end
