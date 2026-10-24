require "rails_helper"

RSpec.describe "Payment screenshots", type: :request do
  let(:plan) { create(:subscription_plan) }
  let(:owner) { create(:user) }

  def submit(file)
    post "/api/v1/subscriptions",
         params: { subscription: { subscription_plan_id: plan.id, payment_method: "instapay",
                                   transaction_reference: "IP-777", payment_screenshot: file } },
         headers: auth_headers(owner)
  end

  it "accepts an image upload with the subscription request" do
    submit(fixture_file_upload("receipt.png", "image/png"))

    expect(response).to have_http_status(:created)
    expect(json.dig("data", "has_payment_screenshot")).to be(true)
    expect(Subscription.last.payment_screenshot).to be_attached
  end

  it "rejects non-image files" do
    submit(fixture_file_upload("receipt.txt", "text/plain"))

    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details")).to have_key("payment_screenshot")
    expect(Subscription.count).to eq(0)
  end

  it "rejects files larger than the size limit" do
    stub_const("Subscription::SCREENSHOT_MAX_SIZE", 10)

    submit(fixture_file_upload("receipt.png", "image/png"))

    expect(response).to have_http_status(:unprocessable_content)
  end

  describe "viewing the screenshot" do
    let(:subscription) do
      create(:subscription, user: owner).tap do |s|
        s.payment_screenshot.attach(io: file_fixture("receipt.png").open, filename: "receipt.png", content_type: "image/png")
      end
    end

    it "redirects the owner to a short-lived URL" do
      get "/api/v1/subscriptions/#{subscription.id}/payment_screenshot", headers: auth_headers(owner)

      expect(response).to have_http_status(:found)
      expect(response.location).to include("/rails/active_storage/disk/")
    end

    it "lets super admins view it" do
      get "/api/v1/admin/subscriptions/#{subscription.id}/payment_screenshot",
          headers: auth_headers(create(:user, :super_admin))

      expect(response).to have_http_status(:found)
    end

    it "hides it from other users" do
      get "/api/v1/subscriptions/#{subscription.id}/payment_screenshot", headers: auth_headers(create(:user))
      expect(response).to have_http_status(:not_found)

      get "/api/v1/admin/subscriptions/#{subscription.id}/payment_screenshot", headers: auth_headers(create(:user))
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 when there is no screenshot" do
      plain = create(:subscription, user: create(:user))
      get "/api/v1/subscriptions/#{plain.id}/payment_screenshot", headers: auth_headers(plain.user)
      expect(response).to have_http_status(:not_found)
    end
  end
end
