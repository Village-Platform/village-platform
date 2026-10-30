require "rails_helper"

RSpec.describe SyncDeviceTopicsJob do
  include ActiveJob::TestHelper

  let!(:everyone) { Topic.everyone }
  let(:news) { create(:topic, :listed, key: "news") }
  let(:owners) { create(:topic, key: "owners") }
  let(:user) { create(:user) }
  let(:fcm) { Fcm.client }

  it "subscribes the token to all and its topics" do
    device = create(:device, token: "t", user:)
    TopicSubscription.create!(topic: news, user:)

    described_class.perform_now(device.id)

    expect(fcm.subscribed).to eq("all" => %w[ t ], "news" => %w[ t ])
  end

  it "unsubscribes from a topic it no longer belongs to" do
    device = create(:device, token: "t")

    described_class.perform_now(device.id, topic_ids: [ news.id ])

    expect(fcm.unsubscribed).to eq("news" => %w[ t ])
    expect(fcm.subscribed).to be_empty
  end

  it "detach removes the user's topics" do
    device = create(:device, token: "t", user:)
    TopicSubscription.create!(topic: owners, user:)

    perform_enqueued_jobs { Devices::Detach.call(device:) }

    expect(fcm.unsubscribed).to eq("owners" => %w[ t ])
  end

  it "keeps a device subscribed directly when its user leaves the topic" do
    device = create(:device, token: "t", user:)
    TopicSubscription.create!(topic: news, device:)

    described_class.perform_now(device.id, topic_ids: [ news.id ])

    expect(fcm.subscribed).to eq("news" => %w[ t ])
  end

  it "deletes a device whose token FCM rejects" do
    device = create(:device, token: "dead")
    fcm.reject_tokens("dead")

    described_class.perform_now(device.id)

    expect(Device.exists?(device.id)).to be(false)
  end

  it "retries the whole reconciliation on Retryable" do
    device = create(:device, token: "t")
    fcm.fail_next_with(Fcm::Retryable.new(retry_after: 5))

    expect { described_class.perform_now(device.id) }.to have_enqueued_job(described_class)
  end

  it "does nothing for a deleted device" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
