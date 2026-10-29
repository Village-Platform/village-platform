require "rails_helper"

RSpec.describe "Subscriptions API", type: :request do
  let(:plan) { create(:subscription_plan, price_cents: 15_000, duration_days: 30) }
  let(:user) { create(:user) }
  let(:params) do
    { subscription: { subscription_plan_id: plan.id, payment_method: "vodafone_cash",
                      transaction_reference: " VF-123 ", payer_phone: "0101 111 2222" } }
  end

  describe "POST /api/v1/subscriptions" do
    it "creates a pending request with the plan price snapshot" do
      post "/api/v1/subscriptions", params:, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("status" => "pending", "amount_cents" => 15_000,
                                      "transaction_reference" => "VF-123", "payer_phone" => "01011112222")
    end

    it "allows only one pending request per user" do
      create(:subscription, user:)

      post "/api/v1/subscriptions", params:, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a reused transfer reference" do
      create(:subscription, payment_method: :vodafone_cash, transaction_reference: "VF-123")

      post "/api/v1/subscriptions", params:, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to have_key("transaction_reference")
    end

    it "rejects an inactive plan" do
      plan.update!(active: false)
      post "/api/v1/subscriptions", params:, headers: auth_headers(user), as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "lets a super admin create a request too" do
      post "/api/v1/subscriptions", params:, headers: auth_headers(create(:user, :super_admin)), as: :json

      expect(response).to have_http_status(:created)
    end

    it "requires authentication" do
      post "/api/v1/subscriptions", params:, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/subscriptions" do
    it "lists only the current user's subscriptions" do
      create(:subscription, user:)
      create(:subscription)

      get "/api/v1/subscriptions", headers: auth_headers(user)

      expect(json["data"].size).to eq(1)
    end
  end

  describe "GET /api/v1/subscription_plans and /payment_methods" do
    it "lists active plans and payment methods publicly" do
      create(:subscription_plan, name: "Monthly")
      create(:subscription_plan, name: "Old", active: false)

      get "/api/v1/subscription_plans"
      expect(json["data"].map { _1["name"] }).to eq([ "Monthly" ])

      get "/api/v1/payment_methods"
      expect(json["data"].map { _1["key"] }).to eq(%w[instapay vodafone_cash])
    end
  end
end
