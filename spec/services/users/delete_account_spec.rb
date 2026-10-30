require "rails_helper"

RSpec.describe Users::DeleteAccount do
  let(:user) { create(:user, :subscribed, email: "owner@example.com") }
  let(:subscription) { user.subscriptions.first }

  before do
    subscription.update!(payer_phone: "01055555555", notes: "paid from my wife's phone")
    subscription.payment_screenshot.attach(io: file_fixture("receipt.png").open, filename: "receipt.png",
                                           content_type: "image/png")
    create(:firm, owner: user)
    Notification.create!(user:, kind: :subscription_approved, title: "t", body: "b")
  end

  it "scrubs the user's personal data and keeps an anonymised tombstone" do
    described_class.call(user:)
    user.reload

    expect(user).to be_deleted
    expect(user).to be_user
    expect(user.name).to eq(described_class::DELETED_NAME)
    expect(user.email).to be_nil
    expect(user.phone.delete("+").length).to be > 15 # longer than any real phone can be
    expect(user.authenticate("password123")).to be(false)
  end

  it "deletes firms and notifications, and strips personal data from payment records" do
    described_class.call(user:)

    expect(Firm.where(owner_id: user.id)).to be_empty
    expect(Notification.where(user_id: user.id)).to be_empty

    subscription.reload
    expect(subscription.payer_phone).to be_nil
    expect(subscription.notes).to be_nil
    expect(subscription.payment_screenshot).not_to be_attached
    expect(subscription.transaction_reference).to be_present # kept for reconciliation
  end

  # Firm is soft-deletable, so the default scope would hide a firm that was only marked deleted.
  it "removes the firm rows themselves, including ones the owner had already deleted" do
    create(:firm, owner: user).destroy

    described_class.call(user:)

    expect(Firm.with_deleted.where(owner_id: user.id)).to be_empty
  end

  it "frees the phone number so it can register again" do
    phone = user.phone
    described_class.call(user:)

    expect(create(:user, phone:)).to be_persisted
  end

  it "refuses super admins" do
    admin = create(:user, :super_admin)
    expect { described_class.call(user: admin) }.to raise_error(ArgumentError)
    expect(admin.reload).not_to be_deleted
  end
end
