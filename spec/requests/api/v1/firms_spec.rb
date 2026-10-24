require "rails_helper"

RSpec.describe "Firms API", type: :request do
  let(:category) { create(:category) }
  let(:owner) { create(:user, :firm_admin) }
  let(:super_admin) { create(:user, :super_admin) }

  describe "GET /api/v1/firms" do
    it "shows only active firms to the public" do
      create(:firm, name: "Visible", category:)
      create(:firm, :pending, name: "Pending", category:)

      get "/api/v1/firms"

      expect(json["data"].map { _1["name"] }).to eq([ "Visible" ])
    end

    it "lets owners see their own pending firms" do
      create(:firm, :pending, name: "Mine", owner:, category:)

      get "/api/v1/firms", params: { mine: true }, headers: auth_headers(owner)

      expect(json["data"].map { _1["name"] }).to eq([ "Mine" ])
    end

    it "filters by category through the nested route and searches by name" do
      other = create(:category)
      create(:firm, name: "Pharmacy Nour", category:)
      create(:firm, name: "Clinic", category:)
      create(:firm, name: "Pharmacy Other", category: other)

      get "/api/v1/categories/#{category.id}/firms", params: { q: "pharm" }

      expect(json["data"].map { _1["name"] }).to eq([ "Pharmacy Nour" ])
    end

    it "hides pending firms from other users on show" do
      firm = create(:firm, :pending, category:)
      get "/api/v1/firms/#{firm.id}", headers: auth_headers(create(:user))
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/firms" do
    let(:params) { { firm: { name: "صيدلية النور", category_id: category.id, status: "active" } } }

    it "lets firm admins create a pending firm (status is not assignable by owners)" do
      post "/api/v1/firms", params:, headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:created)
      expect(json.dig("data", "status")).to eq("pending")
      expect(json.dig("data", "owner_id")).to eq(owner.id)
    end

    it "forbids normal users" do
      post "/api/v1/firms", params:, headers: auth_headers(create(:user)), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/firms/:id" do
    let(:firm) { create(:firm, :pending, owner:, category:) }

    it "lets super admins approve a firm" do
      patch "/api/v1/firms/#{firm.id}", params: { firm: { status: "active" } },
                                        headers: auth_headers(super_admin), as: :json

      expect(response).to have_http_status(:ok)
      expect(firm.reload).to be_active
    end

    it "forbids another firm admin from editing it" do
      other_owner = create(:user, :firm_admin)
      firm.update!(status: :active)

      patch "/api/v1/firms/#{firm.id}", params: { firm: { name: "Hacked" } },
                                        headers: auth_headers(other_owner), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(firm.reload.name).not_to eq("Hacked")
    end
  end
end
