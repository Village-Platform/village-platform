require "rails_helper"

RSpec.describe "Firm ownership", type: :request do
  let(:super_admin) { create(:user, :super_admin) }

  describe "firms without an owner" do
    let!(:firm) { create(:firm, owner: nil, name: "Village bakery") }

    it "are public when active and serve owner_id null" do
      get "/api/v1/firms"

      expect(json["data"].map { _1["name"] }).to eq([ "Village bakery" ])
      expect(json["data"].first["owner_id"]).to be_nil
    end

    it "are managed by super admins only" do
      patch "/api/v1/firms/#{firm.id}", params: { firm: { name: "Changed" } }, headers: auth_headers(create(:user, :subscribed))
      expect(response).to have_http_status(:forbidden)

      patch "/api/v1/firms/#{firm.id}", params: { firm: { name: "Changed" } }, headers: auth_headers(super_admin)
      expect(firm.reload.name).to eq("Changed")
    end

    it "can be created, assigned and unassigned by a super admin through the API" do
      owner = create(:user, :subscribed)

      post "/api/v1/firms", params: { firm: { name: "Mill", category_id: firm.category_id, owner_id: nil } },
                            headers: auth_headers(super_admin)
      created = Firm.find(json["data"]["id"])
      expect(created.owner).to be_nil

      patch "/api/v1/firms/#{created.id}", params: { firm: { owner_id: owner.id } }, headers: auth_headers(super_admin)
      expect(created.reload.owner).to eq(owner)

      patch "/api/v1/firms/#{created.id}", params: { firm: { owner_id: nil } }, headers: auth_headers(super_admin)
      expect(created.reload.owner).to be_nil
    end

    it "can be created and assigned from the dashboard" do
      sign_in_admin

      post "/admin/firms", params: { firm: { name: "Press", category_id: firm.category_id, owner_id: "", status: "active" } }

      expect(Firm.find_by!(name: "Press").owner).to be_nil
      get "/admin/firms/#{Firm.find_by!(name: 'Press').id}"
      expect(response.body).to include("بدون مالك")
    end
  end

  describe "a firm manager" do
    let(:owner) { create(:user, :firm_admin).tap { |u| create(:subscription, :current, user: u, subscription_plan: create(:subscription_plan, max_firms: 3)) } }

    it "manages many firms while subscribed" do
      category = create(:category)
      3.times { |i| post "/api/v1/firms", params: { firm: { name: "Firm #{i}", category_id: category.id } }, headers: auth_headers(owner) }

      expect(owner.firms.count).to eq(3)
      patch "/api/v1/firms/#{owner.firms.first.id}", params: { firm: { name: "Renamed" } }, headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
    end

    it "cannot edit once the subscription has ended, but can still delete" do
      expired = create(:user, :firm_admin).tap { |u| create(:subscription, :expired, user: u) }
      firm = create(:firm, owner: expired)

      patch "/api/v1/firms/#{firm.id}", params: { firm: { name: "Renamed" } }, headers: auth_headers(expired)
      expect(response).to have_http_status(:forbidden)
      expect(json["error"]["code"]).to eq("subscription_required")

      delete "/api/v1/firms/#{firm.id}", headers: auth_headers(expired)
      expect(response).to have_http_status(:no_content)
    end

    it "cannot set the owner of a firm" do
      firm = create(:firm, owner:)

      patch "/api/v1/firms/#{firm.id}", params: { firm: { owner_id: nil } }, headers: auth_headers(owner)

      expect(firm.reload.owner).to eq(owner)
    end
  end

  it "refuses a resident as owner" do
    firm = build(:firm, owner: create(:user))

    expect(firm).not_to be_valid
  end
end
