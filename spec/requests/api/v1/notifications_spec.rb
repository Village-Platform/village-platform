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
end
