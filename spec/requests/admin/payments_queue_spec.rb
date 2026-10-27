require "rails_helper"

RSpec.describe "Payments review queue", type: :request do
  before { sign_in_admin }

  it "lists pending requests oldest first with their age" do
    newer = create(:subscription, created_at: 1.hour.ago)
    older = create(:subscription, created_at: 30.hours.ago)

    get "/admin/subscriptions", params: { status: "pending" }

    expect(response.body.index(older.transaction_reference)).to be < response.body.index(newer.transaction_reference)
    expect(response.body).to include("منذ 30 ساعة")
  end

  it "flags a reference reused with spacing or another method, and a payer phone from another account" do
    create(:subscription, transaction_reference: "tx 123-456", payment_method: :vodafone_cash, payer_phone: "01011112222")
    subscription = create(:subscription, transaction_reference: "TX123456", payer_phone: "01011112222")

    get "/admin/subscriptions/#{subscription.id}"

    expect(response.body).to include("رقم عملية مشابه", "نفس رقم المحوِّل لحساب آخر")
  end

  it "stores the reconciliation note on approval" do
    subscription = create(:subscription)

    patch "/admin/subscriptions/#{subscription.id}/approve", params: { reconciliation_note: "طابق كشف ٢٨" }

    expect(subscription.reload).to have_attributes(status: "active", reconciliation_note: "طابق كشف ٢٨")
  end

  it "shows requests waiting more than a day on the dashboard" do
    create(:subscription, created_at: 2.days.ago)

    get "/admin"

    expect(response.body).to include("طلبات تنتظر أكثر من ٢٤ ساعة")
  end
end
