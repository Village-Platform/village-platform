require "rails_helper"

RSpec.describe "Admin subscription review", type: :request do
  let!(:admin) { sign_in_admin }
  let(:owner) { create(:user) }
  let(:subscription) { create(:subscription, user: owner) }

  it "approves a pending subscription" do
    patch "/admin/subscriptions/#{subscription.id}/approve"

    expect(response).to redirect_to("/admin/subscriptions/#{subscription.id}")
    expect(subscription.reload).to be_active
    expect(subscription.reviewed_by).to eq(admin)
    expect(owner.reload).to be_firm_admin
  end

  it "does not approve twice" do
    patch "/admin/subscriptions/#{subscription.id}/approve"
    patch "/admin/subscriptions/#{subscription.id}/approve"

    expect(flash[:alert]).to be_present
  end

  it "rejects with a reason" do
    patch "/admin/subscriptions/#{subscription.id}/reject", params: { reason: "التحويل غير موجود" }

    expect(subscription.reload).to be_rejected
    expect(subscription.rejection_reason).to eq("التحويل غير موجود")
  end

  it "requires a rejection reason" do
    patch "/admin/subscriptions/#{subscription.id}/reject", params: { reason: " " }

    expect(subscription.reload).to be_pending
    expect(flash[:alert]).to be_present
  end

  it "shows the screenshot through a short-lived redirect" do
    subscription.payment_screenshot.attach(io: file_fixture("receipt.png").open, filename: "r.png", content_type: "image/png")

    get "/admin/subscriptions/#{subscription.id}/screenshot"

    expect(response).to have_http_status(:found)
    expect(response.location).to include("/rails/active_storage/disk/")
  end
end
