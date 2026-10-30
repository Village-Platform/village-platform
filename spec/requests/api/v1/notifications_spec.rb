require "rails_helper"

RSpec.describe "Notifications API", type: :request do
  let(:user) { create(:user) }

  def notify(target = user, key: nil)
    Notifier.notify(user: target, kind: :subscription_rejected, dedupe_key: key, reason: "x")
  end

  it "lists only my notifications with an unread count" do
    notify
    notify.mark_as_read!
    notify(create(:user))

    get "/api/v1/notifications", headers: auth_headers(user)

    expect(json["data"].size).to eq(2)
    expect(json.dig("meta", "unread_count")).to eq(1)
  end

  it "filters unread" do
    notify
    notify.mark_as_read!

    get "/api/v1/notifications", params: { unread: true }, headers: auth_headers(user)

    expect(json["data"].size).to eq(1)
  end

  it "marks one as read and cannot touch others' notifications" do
    mine = notify
    other = notify(create(:user))

    patch "/api/v1/notifications/#{mine.id}/read", headers: auth_headers(user)
    expect(json.dig("data", "read")).to be(true)

    patch "/api/v1/notifications/#{other.id}/read", headers: auth_headers(user)
    expect(response).to have_http_status(:not_found)
  end

  it "marks all as read" do
    2.times { notify }

    patch "/api/v1/notifications/read_all", headers: auth_headers(user)

    expect(response).to have_http_status(:no_content)
    expect(user.notifications.unread.count).to eq(0)
  end

  it "does not create duplicates for the same dedupe key" do
    notify(key: "same")
    notify(key: "same")

    expect(user.notifications.count).to eq(1)
  end

  describe "push" do
    include ActiveJob::TestHelper

    it "enqueues one push per device of the user when notified" do
      devices = create_list(:device, 2, user:)
      create(:device) # someone else's phone

      expect { notify }.to have_enqueued_job(PushNotificationJob).exactly(2).times
      expect(PushNotificationJob).to have_been_enqueued.with(Notification.last.id, devices.first.id)
    end

    it "pushes nothing for a duplicate" do
      create(:device, user:)
      notify(key: "same")
      expect { notify(key: "same") }.not_to have_enqueued_job(PushNotificationJob)
    end

    it "adds the destination to data and keeps subscription_id" do
      subscription = create(:subscription, user:)
      Subscriptions::Reject.call(subscription:, reviewer: create(:user, :super_admin), reason: "صورة غير واضحة")

      data = user.notifications.last.data
      expect(data).to include("subscription_id" => subscription.id, "screen" => "subscription", "id" => subscription.id.to_s)
    end
  end
end
