require "rails_helper"

RSpec.describe "Admin feature flags", type: :request do
  before { sign_in_admin }

  it "lists flags with a working toggle" do
    flag = create(:feature_flag, key: "plans", description: "إظهار الباقات")

    get "/admin/feature_flags"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("plans", "إظهار الباقات", "/admin/feature_flags/#{flag.id}/toggle")
  end

  it "toggles a flag on and off, and the API follows" do
    flag = create(:feature_flag, key: "plans", enabled: false)

    patch "/admin/feature_flags/#{flag.id}/toggle"
    expect(response).to redirect_to("/admin/feature_flags")
    expect(flag.reload.enabled).to be(true)

    get "/api/v1/app_config"
    expect(json["data"]["features"]["plans"]).to be(true)

    patch "/admin/feature_flags/#{flag.id}/toggle"
    expect(flag.reload.enabled).to be(false)
  end

  it "creates a flag and rejects an invalid or duplicate key" do
    post "/admin/feature_flags", params: { feature_flag: { key: "reviews", description: "التقييمات", enabled: "1" } }
    expect(response).to redirect_to("/admin/feature_flags")
    expect(FeatureFlag.find_by!(key: "reviews").enabled).to be(true)

    post "/admin/feature_flags", params: { feature_flag: { key: "Bad Key" } }
    expect(response).to have_http_status(:unprocessable_content)

    post "/admin/feature_flags", params: { feature_flag: { key: "reviews" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "never changes the key on update, because the apps read the flag by it" do
    flag = create(:feature_flag, key: "plans")

    patch "/admin/feature_flags/#{flag.id}", params: { feature_flag: { key: "renamed", description: "جديد" } }

    expect(response).to redirect_to("/admin/feature_flags")
    expect(flag.reload).to have_attributes(key: "plans", description: "جديد")
  end

  it "deletes a flag, which the API then reports as off" do
    flag = create(:feature_flag, key: "plans", enabled: true)

    delete "/admin/feature_flags/#{flag.id}"

    expect(FeatureFlag.exists?(flag.id)).to be(false)
    get "/api/v1/app_config"
    expect(json["data"]["features"]["plans"]).to be(false)
  end

  it "is closed to anyone who is not a signed-in super admin" do
    delete "/admin/logout"

    get "/admin/feature_flags"

    expect(response).to redirect_to("/admin/login")
  end
end
