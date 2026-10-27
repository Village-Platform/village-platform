require "rails_helper"

RSpec.describe "Subscription entitlements and listing priority", type: :request do
  def subscriber_on(plan)
    create(:user, :firm_admin).tap { |user| create(:subscription, :current, user:, subscription_plan: plan) }
  end

  describe "plan defaults" do
    it "keep today's behaviour for a plan created without the new limits" do
      plan = create(:subscription_plan)

      expect(plan).to have_attributes(max_images_per_firm: 5, max_videos_per_firm: 0, max_video_seconds: 60,
                                      max_articles_per_month: 0, priority: 0)
    end

    it "are exposed on the public plan list" do
      create(:subscription_plan, max_videos_per_firm: 2, priority: 50)

      get "/api/v1/subscription_plans"

      expect(json["data"].first).to include("max_videos_per_firm" => 2, "priority" => 50, "max_images_per_firm" => 5)
    end
  end

  describe "GET /api/v1/me" do
    it "returns the plan limits and current usage" do
      user = subscriber_on(create(:subscription_plan, max_firms: 3, max_articles_per_month: 4))
      create(:firm, owner: user)

      get "/api/v1/me", headers: auth_headers(user)

      expect(json["data"]["entitlements"]).to include("max_firms" => 3, "max_articles_per_month" => 4,
                                                      "usage" => { "firms" => 1, "articles_this_month" => 0 })
    end

    it "returns zero limits without a subscription and nil (unlimited) for super admins" do
      get "/api/v1/me", headers: auth_headers(create(:user))
      expect(json["data"]["entitlements"]["max_firms"]).to eq(0)

      get "/api/v1/me", headers: auth_headers(create(:user, :super_admin))
      expect(json["data"]["entitlements"]["max_firms"]).to be_nil
    end
  end

  describe "listing order" do
    it "puts subscribers above the super admin's places, higher priority first, then by name" do
      super_admin = create(:user, :super_admin)
      basic = subscriber_on(create(:subscription_plan, priority: 0))
      premium = subscriber_on(create(:subscription_plan, priority: 80))

      create(:firm, name: "A place", owner: super_admin)
      create(:firm, name: "B basic", owner: basic)
      create(:firm, name: "C premium", owner: premium)
      create(:firm, name: "A basic", owner: basic)

      get "/api/v1/firms"

      expect(json["data"].map { _1["name"] }).to eq([ "C premium", "A basic", "B basic", "A place" ])
      expect(json["meta"]["total"]).to eq(4)
    end

    it "drops a firm back down once its owner's premium period has ended" do
      premium_plan = create(:subscription_plan, priority: 80)
      owner = create(:user, :firm_admin)
      create(:subscription, :current, user: owner, subscription_plan: create(:subscription_plan, priority: 0))
      create(:subscription, :expired, user: owner, subscription_plan: premium_plan, transaction_reference: "OLD1")
      create(:firm, name: "Z owner", owner:)
      create(:firm, name: "A other", owner: subscriber_on(create(:subscription_plan, priority: 10)))

      get "/api/v1/firms"

      expect(json["data"].map { _1["name"] }).to eq([ "A other", "Z owner" ])
    end
  end

  it "keeps the firm quota check working through entitlements" do
    user = subscriber_on(create(:subscription_plan, max_firms: 1))
    create(:firm, owner: user)

    post "/api/v1/firms", params: { firm: { name: "Second", category_id: create(:category).id } }, headers: auth_headers(user)

    expect(response).to have_http_status(:forbidden)
    expect(json["error"]["code"]).to eq("subscription_required")
  end
end
