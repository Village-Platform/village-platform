require "rails_helper"

RSpec.describe "Me API", type: :request do
  describe "DELETE /api/v1/me" do
    let(:user) { create(:user, password: "password123") }

    it "turns the account's phones into guests and drops its topics" do
      device = create(:device, user:)
      TopicSubscription.create!(topic: create(:topic), user:)

      delete "/api/v1/me", params: { password: "password123" }, headers: auth_headers(user), as: :json

      expect(device.reload.user).to be_nil
      expect(TopicSubscription.count).to eq(0)
    end

    it "deletes the account and revokes the token" do
      delete "/api/v1/me", params: { password: "password123" }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:no_content)
      expect(user.reload).to be_deleted

      get "/api/v1/me", headers: auth_headers(user)
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a wrong password with 422, not 401, so the app keeps the session" do
      delete "/api/v1/me", params: { password: "wrong-pass" }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("invalid_password")
      expect(user.reload).not_to be_deleted
    end

    it "requires the password" do
      delete "/api/v1/me", headers: auth_headers(user), as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "requires authentication" do
      delete "/api/v1/me", params: { password: "password123" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses super admins" do
      admin = create(:user, :super_admin, password: "password123")
      delete "/api/v1/me", params: { password: "password123" }, headers: auth_headers(admin), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(admin.reload).not_to be_deleted
    end
  end
end
