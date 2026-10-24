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
end
