require "rails_helper"

RSpec.describe SubscriptionExpiryRemindersJob, type: :job do
  let(:owner) { create(:user, :firm_admin) }
  let(:plan) { create(:subscription_plan, name: "شهري") }

  def subscription(ends_in:)
    create(:subscription, user: owner, subscription_plan: plan, status: :active,
                          starts_at: 30.days.ago, ends_at: ends_in.from_now)
  end

  it "sends a 7-day reminder once, even if run twice" do
    subscription(ends_in: 6.days)

    2.times { described_class.perform_now }

    expect(owner.notifications.subscription_expiring.count).to eq(1)
    expect(owner.notifications.last.data).to include("days_left" => 6)
  end

  it "counts runs, sent reminders and deduplicated ones", :metrics do
    subscription(ends_in: -1.day)

    2.times { described_class.perform_now }

    expect(metric_value("aghour.reminders.runs", result: "success")).to eq(2)
    expect(metric_value("aghour.reminders.runs", result: "failure")).to eq(0)
    expect(metric_value("aghour.reminders.sent")).to eq(1)
    expect(metric_value("aghour.notifications.created", kind: "subscription_expired")).to eq(1)
    expect(metric_value("aghour.notifications.deduplicated", kind: "subscription_expired")).to eq(1)
  end

  it "counts a failed run and still raises", :metrics do
    allow(Subscription).to receive(:current).and_raise(ActiveRecord::ConnectionNotEstablished)

    expect { described_class.perform_now }.to raise_error(ActiveRecord::ConnectionNotEstablished)
    expect(metric_value("aghour.reminders.runs", result: "failure")).to eq(1)
  end

  it "sends a separate 1-day reminder" do
    sub = subscription(ends_in: 6.days)
    described_class.perform_now

    travel_to(sub.ends_at - 12.hours) { described_class.perform_now }

    expect(owner.notifications.subscription_expiring.count).to eq(2)
  end

  it "notifies after expiry" do
    subscription(ends_in: -1.day)

    described_class.perform_now

    expect(owner.notifications.subscription_expired.count).to eq(1)
  end

  it "skips owners who already renewed" do
    current = subscription(ends_in: 3.days)
    create(:subscription, user: owner, subscription_plan: plan, status: :active,
                          starts_at: current.ends_at, ends_at: current.ends_at + 30.days)

    described_class.perform_now

    expect(owner.notifications).to be_empty
  end

  it "ignores subscriptions far from expiry" do
    subscription(ends_in: 20.days)
    described_class.perform_now
    expect(owner.notifications).to be_empty
  end
end
