require "rails_helper"

RSpec.describe "Topics API", type: :request do
  let!(:news) { create(:topic, :listed, key: "news", name: "الأخبار") }
  let!(:hidden) { create(:topic, key: "owners") }
  let(:user) { create(:user) }
  let(:device) { create(:device, installation_id: "phone-a") }

  def toggle(method, key, headers: {})
    public_send(method, "/api/v1/devices/phone-a/topics/#{key}", headers:)
  end

  it "lists public topics with subscribed for this device" do
    Topic.everyone
    TopicSubscription.create!(topic: news, device:)

    get "/api/v1/topics", headers: { "X-Installation-Id" => "phone-a" }

    expect(json["data"]).to eq([ { "key" => "news", "name" => "الأخبار", "description" => nil, "subscribed" => true } ])
  end

  it "reports subscribed false for an unknown installation" do
    get "/api/v1/topics", headers: { "X-Installation-Id" => "nope" }
    expect(json["data"].map { |t| t["subscribed"] }).to eq([ false ])
  end

  it "counts a signed-in user's own subscription" do
    TopicSubscription.create!(topic: news, user:)
    get "/api/v1/topics", headers: auth_headers(user)
    expect(json.dig("data", 0, "subscribed")).to be(true)
  end

  it "lets a guest opt in and out per device" do
    device
    expect { toggle(:put, "news") }.to have_enqueued_job(SyncDeviceTopicsJob).with(device.id, topic_ids: [ news.id ])
    expect(response).to have_http_status(:ok)
    expect(TopicSubscription.sole).to have_attributes(device_id: device.id, user_id: nil)

    toggle(:delete, "news")
    expect(response).to have_http_status(:ok)
    expect(TopicSubscription.count).to eq(0)
  end

  it "subscribes a signed-in user at user level and resyncs all their devices" do
    device.update!(user:)
    other_device = create(:device, user:)

    expect { toggle(:put, "news", headers: auth_headers(user)) }
      .to have_enqueued_job(SyncDeviceTopicsJob).with(device.id, topic_ids: [ news.id ])
      .and have_enqueued_job(SyncDeviceTopicsJob).with(other_device.id, topic_ids: [ news.id ])
    expect(TopicSubscription.sole).to have_attributes(user_id: user.id, device_id: nil)
  end

  it "lets a signed-in user leave a topic they joined as a guest" do
    TopicSubscription.create!(topic: news, device:)
    device.update!(user:)

    toggle(:delete, "news", headers: auth_headers(user))

    expect(json.dig("data", "subscribed")).to be(false)
    expect(TopicSubscription.count).to eq(0)
  end

  it "is idempotent" do
    device
    2.times { toggle(:put, "news") }
    expect(response).to have_http_status(:ok)
    expect(TopicSubscription.count).to eq(1)
  end

  it "refuses non-public and system topics" do
    device
    toggle(:put, "owners")
    expect(response).to have_http_status(:not_found)
    toggle(:put, Topic.everyone.key)
    expect(response).to have_http_status(:not_found)
  end

  it "refuses an anonymous toggle on a user's device" do
    device.update!(user:)
    toggle(:put, "news")
    expect(response).to have_http_status(:forbidden)
  end

  it "refuses a signed-in user on someone else's device" do
    device.update!(user: create(:user))
    toggle(:put, "news", headers: auth_headers(user))
    expect(response).to have_http_status(:forbidden)
  end
end
