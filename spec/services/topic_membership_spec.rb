require "rails_helper"

RSpec.describe "Topic membership" do
  let!(:everyone) { create(:topic, key: Topic::EVERYONE_KEY, system: true) }
  let(:news) { create(:topic, :listed, key: "news") }
  let(:user) { create(:user) }

  it "puts a device in a topic through its user" do
    device = create(:device, user:)
    TopicSubscription.create!(topic: news, user:)

    expect(device.topic_keys).to eq(%w[ all news ])
    expect(news.devices).to contain_exactly(device)
  end

  it "puts a guest device in a topic directly" do
    device = create(:device)
    TopicSubscription.create!(topic: news, device:)

    expect(news.devices).to contain_exactly(device)
    expect(device.topic_keys).to eq(%w[ all news ])
  end

  it "counts a device once when it is subscribed directly and through its user" do
    device = create(:device, user:)
    TopicSubscription.create!(topic: news, user:)
    TopicSubscription.create!(topic: news, device:)

    expect(news.devices.to_a).to eq([ device ])
    expect(device.topic_keys).to eq(%w[ all news ])
  end

  it "puts every device in the everyone topic" do
    devices = create_list(:device, 2)
    expect(everyone.devices).to match_array(devices)
  end

  it "rejects a subscription with both a user and a device" do
    expect {
      TopicSubscription.insert_all!([ { topic_id: news.id, user_id: user.id, device_id: create(:device).id,
                                        created_at: Time.current, updated_at: Time.current } ])
    }.to raise_error(ActiveRecord::StatementInvalid, /check/i)
  end

  it "lists recipients through users and their devices, without soft-deleted users" do
    direct = create(:user)
    through_device = create(:user)
    deleted = create(:user)
    TopicSubscription.create!(topic: news, user: direct)
    TopicSubscription.create!(topic: news, device: create(:device, user: through_device))
    TopicSubscription.create!(topic: news, user: deleted)
    TopicSubscription.create!(topic: news, device: create(:device)) # guest: no inbox
    deleted.destroy

    expect(Topic.recipient_user_ids([ news ])).to contain_exactly(direct.id, through_device.id)
  end

  it "makes every non-deleted user a recipient of the everyone topic" do
    users = create_list(:user, 2)
    create(:user).destroy

    expect(Topic.recipient_user_ids([ everyone, news ])).to match_array(users.map(&:id))
  end

  it "creates the everyone topic when a database was seeded before topics existed" do
    everyone.delete
    expect(Topic.everyone).to have_attributes(key: "all", system: true)
  end

  it "refuses to destroy the system topic" do
    expect(everyone.destroy).to be(false)
    expect(everyone.errors[:base]).to be_present
  end

  it "keeps the key read-only" do
    expect { news.update!(key: "renamed") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
  end
end
