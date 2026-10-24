require "rails_helper"

RSpec.describe "Auth API", type: :request do
  describe "POST /api/v1/auth/register" do
    it "creates a normal user and returns a token" do
      post "/api/v1/auth/register", params: {
        user: { name: "Ahmed", phone: "0101 234 5678", password: "password123", role: "super_admin" }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json.dig("data", "token")).to be_present
      expect(json.dig("data", "user", "phone")).to eq("01012345678")
      expect(json.dig("data", "user", "role")).to eq("user") # role is not mass-assignable
    end

    it "returns validation errors" do
      post "/api/v1/auth/register", params: { user: { name: "", phone: "1", password: "x" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("validation_failed")
      expect(json.dig("error", "details").keys).to include("name", "phone", "password")
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, phone: "01099999999", password: "password123") }

    it "returns a token for valid credentials" do
      post "/api/v1/auth/login", params: { phone: "01099999999", password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "user", "id")).to eq(user.id)
    end

    it "rejects a wrong password" do
      post "/api/v1/auth/login", params: { phone: "01099999999", password: "wrong-pass" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json.dig("error", "code")).to eq("invalid_credentials")
    end
  end

  describe "GET /api/v1/me" do
    it "requires a token" do
      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an invalid token" do
      get "/api/v1/me", headers: { "Authorization" => "Bearer nope" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the current user" do
      user = create(:user)
      get "/api/v1/me", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "id")).to eq(user.id)
    end
  end
end
