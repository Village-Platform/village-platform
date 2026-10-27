require "rails_helper"

RSpec.describe "Categories API", type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:user) { create(:user) }

  describe "GET /api/v1/categories" do
    it "lists only active categories for the public, ordered by position" do
      create(:category, name: "B", position: 2)
      create(:category, name: "A", position: 1)
      create(:category, name: "Hidden", active: false)

      get "/api/v1/categories"

      expect(response).to have_http_status(:ok)
      expect(json["data"].map { _1["name"] }).to eq(%w[A B])
      expect(json["meta"]).to include("page" => 1, "total" => 2)
    end

    it "shows inactive categories to super admins" do
      create(:category, active: false)
      get "/api/v1/categories", headers: auth_headers(super_admin)
      expect(json["data"].size).to eq(1)
    end
  end

  describe "POST /api/v1/categories" do
    let(:params) { { category: { name: "أطباء", position: 1 } } }

    it "allows super admins" do
      post "/api/v1/categories", params:, headers: auth_headers(super_admin), as: :json
      expect(response).to have_http_status(:created)
      expect(json.dig("data", "name")).to eq("أطباء")
    end

    it "forbids normal users" do
      post "/api/v1/categories", params:, headers: auth_headers(user), as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "requires authentication" do
      post "/api/v1/categories", params:, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/categories/:id" do
    it "refuses to delete a category that has firms" do
      category = create(:category)
      create(:firm, category:)

      delete "/api/v1/categories/#{category.id}", headers: auth_headers(super_admin)

      expect(response).to have_http_status(:unprocessable_content)
      expect(category.reload).to be_present
    end
  end

  describe "category icon images" do
    def attach_icon(category, fixture = "receipt.png", type = "image/png")
      category.icon_image.attach(io: file_fixture(fixture).open, filename: fixture, content_type: type)
    end

    it "lists icon_url (with a content version) only for categories that have an image" do
      with_icon = create(:category, position: 1, icon: "doctor")
      attach_icon(with_icon)
      create(:category, position: 2)

      get "/api/v1/categories"

      first, second = json["data"]
      expect(first["icon"]).to eq("doctor")
      expect(first["icon_url"]).to eq("/api/v1/categories/#{with_icon.id}/icon?v=#{with_icon.reload.icon_version}")
      expect(second["icon_url"]).to be_nil
    end

    it "includes the category icon in firm responses" do
      firm = create(:firm)
      attach_icon(firm.category)

      get "/api/v1/firms/#{firm.id}"

      expect(json.dig("data", "category", "icon_url")).to eq(firm.category.reload.icon_url)
    end

    it "serves the image publicly, cached for a year when the version matches" do
      category = create(:category)
      attach_icon(category)

      get category.reload.icon_url

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
      expect(response.body.bytesize).to eq(file_fixture("receipt.png").size)
      expect(response.headers["Cache-Control"]).to include("public", "max-age=#{1.year.to_i}", "immutable")
    end

    it "caches for an hour only when the version is missing or old" do
      category = create(:category)
      attach_icon(category)

      get "/api/v1/categories/#{category.id}/icon", params: { v: "old" }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to include("public", "max-age=3600")
      expect(response.headers["Cache-Control"]).not_to include("immutable")
    end

    it "answers 404 without an image or for a hidden category" do
      get "/api/v1/categories/#{create(:category).id}/icon"
      expect(response).to have_http_status(:not_found)

      hidden = create(:category, active: false)
      attach_icon(hidden)
      get "/api/v1/categories/#{hidden.id}/icon"
      expect(response).to have_http_status(:not_found)
    end

    it "lets super admins upload an image and rejects files that are not images" do
      category = create(:category)

      patch "/api/v1/categories/#{category.id}", headers: auth_headers(super_admin),
            params: { category: { icon_image: fixture_file_upload("receipt.png", "image/png") } }
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "icon_url")).to be_present

      patch "/api/v1/categories/#{category.id}", headers: auth_headers(super_admin),
            params: { category: { icon_image: fixture_file_upload("receipt.txt", "text/plain") } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
