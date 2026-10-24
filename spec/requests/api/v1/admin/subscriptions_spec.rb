require "rails_helper"

RSpec.describe "Admin Subscriptions API", type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:owner) { create(:user) }
  let(:plan) { create(:subscription_plan, duration_days: 30) }
  let(:subscription) { create(:subscription, user: owner, subscription_plan: plan) }

  describe "PATCH approve" do
    it "activates the subscription and promotes the user to firm admin" do
      freeze_time do
        patch "/api/v1/admin/subscriptions/#{subscription.id}/approve", headers: auth_headers(super_admin)

        expect(response).to have_http_status(:ok)
        expect(json.dig("data", "state")).to eq("current")
        expect(subscription.reload.ends_at).to eq(30.days.from_now)
        expect(subscription.reviewed_by).to eq(super_admin)
        expect(owner.reload).to be_firm_admin
      end
    end

    it "stacks a renewal after the remaining time" do
      current = create(:subscription, :current, user: owner)

      patch "/api/v1/admin/subscriptions/#{subscription.id}/approve", headers: auth_headers(super_admin)

      expect(subscription.reload.starts_at).to be_within(1.second).of(current.ends_at)
      expect(json.dig("data", "state")).to eq("scheduled")
    end

    it "cannot approve twice" do
      patch "/api/v1/admin/subscriptions/#{subscription.id}/approve", headers: auth_headers(super_admin)
      patch "/api/v1/admin/subscriptions/#{subscription.id}/approve", headers: auth_headers(super_admin)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("invalid_state")
    end

    it "forbids non super admins" do
      patch "/api/v1/admin/subscriptions/#{subscription.id}/approve", headers: auth_headers(owner)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH reject" do
    it "rejects with a reason" do
      patch "/api/v1/admin/subscriptions/#{subscription.id}/reject",
            params: { reason: "Transfer not found" }, headers: auth_headers(super_admin), as: :json

      expect(json.dig("data", "status")).to eq("rejected")
      expect(json.dig("data", "rejection_reason")).to eq("Transfer not found")
      expect(owner.reload).to be_user
    end

    it "requires a reason" do
      patch "/api/v1/admin/subscriptions/#{subscription.id}/reject", headers: auth_headers(super_admin), as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET index" do
    it "filters the review queue by status" do
      create(:subscription, status: :rejected)
      subscription

      get "/api/v1/admin/subscriptions", params: { status: "pending" }, headers: auth_headers(super_admin)

      expect(json["data"].map { _1["id"] }).to eq([ subscription.id ])
      expect(json.dig("data", 0, "user", "id")).to eq(owner.id)
    end
  end
end
