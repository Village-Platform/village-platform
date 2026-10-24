require "rails_helper"

# Smoke test: every dashboard page renders with data in it.
RSpec.describe "Admin pages", type: :request do
  let!(:admin) { sign_in_admin }

  before do
    firm = create(:firm)
    create(:firm, :pending, owner: firm.owner, category: firm.category)
    create(:subscription)
    create(:article)
    create(:subscription_plan)
  end

  %w[
    /admin /admin/subscriptions /admin/firms /admin/firms/new /admin/categories /admin/categories/new
    /admin/articles /admin/articles/new /admin/subscription_plans /admin/subscription_plans/new
    /admin/users /admin/users/new
  ].each do |path|
    it "renders #{path}" do
      get path
      expect(response).to have_http_status(:ok)
    end
  end

  it "renders show and edit pages" do
    firm = Firm.first
    user = firm.owner
    subscription = Subscription.first

    [ "/admin/firms/#{firm.id}", "/admin/firms/#{firm.id}/edit", "/admin/users/#{user.id}",
      "/admin/users/#{user.id}/edit", "/admin/subscriptions/#{subscription.id}",
      "/admin/categories/#{firm.category_id}/edit", "/admin/articles/#{Article.first.id}/edit",
      "/admin/subscription_plans/#{SubscriptionPlan.first.id}/edit" ].each do |path|
      get path
      expect(response).to have_http_status(:ok), "expected #{path} to render"
    end
  end

  it "filters and searches without errors" do
    get "/admin/subscriptions", params: { status: "pending", payment_method: "instapay", q: "TX" }
    expect(response).to have_http_status(:ok)

    get "/admin/firms", params: { status: "active", q: "Firm" }
    expect(response).to have_http_status(:ok)

    get "/admin/users", params: { role: "firm_admin", q: "01" }
    expect(response).to have_http_status(:ok)
  end
end
