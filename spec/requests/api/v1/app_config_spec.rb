require "rails_helper"

RSpec.describe "App config API", type: :request do
  describe "GET /api/v1/app_config" do
    it "reports plans as off when no flag row exists (features fail closed)" do
      get "/api/v1/app_config"

      expect(response).to have_http_status(:ok)
      expect(json["data"]["features"]).to eq("plans" => false)
    end

    it "reflects the flags managed from the dashboard, without authentication" do
      create(:feature_flag, key: "plans", enabled: true)
      create(:feature_flag, key: "reviews", enabled: false)

      get "/api/v1/app_config"

      expect(json["data"]["features"]).to eq("plans" => true, "reviews" => false)
    end

    it "is publicly cacheable for five minutes" do
      get "/api/v1/app_config"

      expect(response.headers["Cache-Control"]).to include("public", "max-age=300")
    end
  end
end
