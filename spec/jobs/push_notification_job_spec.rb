require "rails_helper"

RSpec.describe PushNotificationJob do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:device) { create(:device, user:, token: "t") }
  let(:notification) do
    user.notifications.create!(kind: :subscription_rejected, title: "T", body: "B",
                               data: { "subscription_id" => 5, "screen" => "subscription", "id" => "5" })
  end
  let(:fcm) { Fcm.client }

  it "pushes title, body and destination to the device" do
    described_class.perform_now(notification.id, device.id)

    message = fcm.deliveries.sole
    expect(message[:token]).to eq("t")
    expect(message[:notification]).to eq(title: "T", body: "B")
    expect(message[:data]).to include("screen" => "subscription", "id" => "5", "notification_id" => notification.id.to_s)
  end

  it "does not push to a detached device" do
    device.update!(user: nil)
    described_class.perform_now(notification.id, device.id)
    expect(fcm.deliveries).to be_empty
  end

  it "does nothing when the device or notification is gone" do
    described_class.perform_now(0, device.id)
    described_class.perform_now(notification.id, 0)
    expect(fcm.deliveries).to be_empty
  end

  it "deletes the device on Unregistered", :metrics do
    fcm.fail_next_with(Fcm::Unregistered.new)
    described_class.perform_now(notification.id, device.id)

    expect(Device.exists?(device.id)).to be(false)
    expect(metric_value("aghour.push.tokens_pruned")).to eq(1)
    expect(metric_value("aghour.push.sent", source: "system", result: "unregistered")).to eq(1)
  end

  it "keeps the token on InvalidArgument", :metrics do
    fcm.fail_next_with(Fcm::InvalidArgument.new)
    described_class.perform_now(notification.id, device.id)

    expect(Device.exists?(device.id)).to be(true)
    expect(metric_value("aghour.push.sent", source: "system", result: "invalid")).to eq(1)
  end

  it "retries no sooner than Retry-After on Retryable" do
    fcm.fail_next_with(Fcm::Retryable.new(retry_after: 30))
    freeze_time do
      expect { described_class.perform_now(notification.id, device.id) }
        .to have_enqueued_job(described_class).at(30.seconds.from_now)
    end
  end

  it "stops without retry on AuthError", :metrics do
    fcm.fail_next_with(Fcm::AuthError.new)
    expect { described_class.perform_now(notification.id, device.id) }.not_to have_enqueued_job(described_class)
    expect(metric_value("aghour.push.sent", source: "system", result: "auth_error")).to eq(1)
  end

  it "counts a successful push", :metrics do
    described_class.perform_now(notification.id, device.id)
    expect(metric_value("aghour.push.sent", source: "system", result: "ok")).to eq(1)
  end
end
