require "rails_helper"

RSpec.describe "Observability metrics", :metrics, type: :request do
  describe "HTTP requests" do
    it "records duration by route, method, status and surface" do
      get "/api/v1/categories"

      expect(metric_value("http.server.request.duration",
                          "http.route" => "Api::V1::CategoriesController#index",
                          "http.request.method" => "GET",
                          "http.response.status_code" => 200,
                          "app.surface" => "api")).to eq(1)
    end

    it "leaves the health check out" do
      get "/up"

      expect(metric_value("http.server.request.duration")).to eq(0)
    end

    it "counts API clients by platform and major.minor app version" do
      get "/api/v1/categories", headers: { "X-App-Platform" => "Android", "X-App-Version" => "1.4.2 (build 87)" }
      get "/api/v1/categories"
      get "/api/v1/categories", headers: { "X-App-Platform" => "<script>", "X-App-Version" => "latest" }

      expect(metric_value("aghour.api.client_requests", "client.platform" => "android", "client.app_version" => "1.4")).to eq(1)
      expect(metric_value("aghour.api.client_requests", "client.platform" => "unknown", "client.app_version" => "unknown")).to eq(2)
    end
  end

  it "counts error responses by code and status" do
    get "/api/v1/firms/0"

    expect(metric_value("aghour.api.errors", code: "not_found", status: 404)).to eq(1)
  end

  describe "auth" do
    let!(:user) { create(:user, phone: "01099999999", password: "password123") }

    it "counts API logins by result" do
      post "/api/v1/auth/login", params: { phone: "01099999999", password: "password123" }, as: :json
      post "/api/v1/auth/login", params: { phone: "01099999999", password: "wrong" }, as: :json

      expect(metric_value("aghour.auth.logins", surface: "api", result: "success")).to eq(1)
      expect(metric_value("aghour.auth.logins", surface: "api", result: "invalid_credentials")).to eq(1)
    end

    it "counts dashboard logins, including rejected non-admins" do
      sign_in_admin
      post "/admin/login", params: { phone: user.phone, password: "password123" }

      expect(metric_value("aghour.auth.logins", surface: "admin", result: "success")).to eq(1)
      expect(metric_value("aghour.auth.logins", surface: "admin", result: "invalid_credentials")).to eq(1)
    end

    it "counts registrations" do
      post "/api/v1/auth/register", params: {
        user: { name: "Owner", phone: "01055555555", password: "password123", password_confirmation: "password123" }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(metric_value("aghour.auth.registrations")).to eq(1)
    end
  end

  describe "subscriptions" do
    let(:super_admin) { create(:user, :super_admin) }
    let(:plan) { create(:subscription_plan, name: "شهري") }

    it "counts requests by payment method and plan" do
      post "/api/v1/subscriptions", params: {
        subscription: { subscription_plan_id: plan.id, payment_method: "vodafone_cash", transaction_reference: "VF-1" }
      }, headers: auth_headers(create(:user)), as: :json

      expect(response).to have_http_status(:created)
      expect(metric_value("aghour.subscriptions.requested", payment_method: "vodafone_cash", plan: "شهري")).to eq(1)
    end

    it "counts reviews by outcome and records how long they waited" do
      waited = create(:subscription, subscription_plan: plan, created_at: 3.hours.ago)
      rejected = create(:subscription, subscription_plan: plan)

      patch "/api/v1/admin/subscriptions/#{waited.id}/approve", headers: auth_headers(super_admin)
      patch "/api/v1/admin/subscriptions/#{rejected.id}/reject", params: { reason: "no transfer" },
                                                                 headers: auth_headers(super_admin), as: :json

      expect(metric_value("aghour.subscriptions.reviewed", outcome: "approved")).to eq(1)
      expect(metric_value("aghour.subscriptions.reviewed", outcome: "rejected")).to eq(1)
      wait = metric_points("aghour.subscription.review.wait", outcome: "approved").sole
      expect(wait.sum).to be_within(60).of(3.hours.to_i)
    end

    it "reports pending subscriptions and the oldest one's age" do
      create(:subscription, subscription_plan: plan, created_at: 2.days.ago)
      create(:subscription, subscription_plan: plan)
      create(:subscription, :current, subscription_plan: plan)

      expect(metric_value("aghour.subscriptions.pending")).to eq(2)
      expect(metric_value("aghour.subscriptions.pending.oldest_age")).to be_within(60).of(2.days.to_i)
      expect(metric_value("aghour.subscriptions.current")).to eq(1)
    end
  end
end
