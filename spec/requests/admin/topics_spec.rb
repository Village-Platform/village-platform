require "rails_helper"

RSpec.describe "Admin topics", type: :request do
  include ActiveJob::TestHelper

  context "signed in" do
    before { sign_in_admin }

    it "lists topics with member counts" do
      topic = create(:topic, key: "owners", name: "أصحاب الأنشطة")
      TopicSubscription.create!(topic:, user: create(:user))

      get "/admin/topics"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("owners", "أصحاب الأنشطة")
    end

    it "creates a topic" do
      post "/admin/topics", params: { topic: { key: "offers", name: "العروض", public: "1" } }

      expect(response).to redirect_to("/admin/topics/#{Topic.last.id}")
      expect(Topic.find_by!(key: "offers")).to have_attributes(name: "العروض", public: true)
    end

    it "rejects an invalid key" do
      post "/admin/topics", params: { topic: { key: "Bad Key", name: "x" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "cannot rename the key on update" do
      topic = create(:topic, key: "offers")
      patch "/admin/topics/#{topic.id}", params: { topic: { key: "other", name: "اسم جديد" } }

      expect(topic.reload).to have_attributes(key: "offers", name: "اسم جديد")
    end

    it "cannot edit or delete the everyone topic" do
      everyone = Topic.everyone
      patch "/admin/topics/#{everyone.id}", params: { topic: { name: "x" } }
      expect(response).to redirect_to("/admin/topics/#{everyone.id}")
      expect(everyone.reload.name).to eq("الجميع")

      delete "/admin/topics/#{everyone.id}"
      expect(Topic.exists?(everyone.id)).to be(true)
    end

    it "deletes a topic and its memberships" do
      topic = create(:topic)
      TopicSubscription.create!(topic:, user: create(:user))
      delete "/admin/topics/#{topic.id}"

      expect(Topic.exists?(topic.id)).to be(false)
      expect(TopicSubscription.count).to eq(0)
    end

    it "refuses to delete a topic a campaign used" do
      topic = create(:topic)
      create(:notification_campaign, topics: [ topic ])

      delete "/admin/topics/#{topic.id}"

      expect(response).to redirect_to("/admin/topics")
      expect(flash[:alert]).to be_present
      expect(Topic.exists?(topic.id)).to be(true)
    end

    it "shows members and finds users to add" do
      topic = create(:topic)
      member = create(:user, name: "سعيد")
      create(:user, name: "سعاد")
      TopicSubscription.create!(topic:, user: member)

      get "/admin/topics/#{topic.id}", params: { q: "سعاد" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("سعيد", "سعاد")
    end

    it "adds a member and resyncs their devices" do
      topic = create(:topic)
      user = create(:user)
      device = create(:device, user:)

      expect { post "/admin/topics/#{topic.id}/members", params: { user_id: user.id } }
        .to have_enqueued_job(SyncDeviceTopicsJob).with(device.id, topic_ids: [ topic.id ])
      expect(TopicSubscription.sole).to have_attributes(topic_id: topic.id, user_id: user.id)

      post "/admin/topics/#{topic.id}/members", params: { user_id: user.id }
      expect(TopicSubscription.count).to eq(1)
    end

    it "removes a member and resyncs their devices" do
      topic = create(:topic)
      user = create(:user)
      device = create(:device, user:)
      TopicSubscription.create!(topic:, user:)

      expect { delete "/admin/topics/#{topic.id}/members/#{user.id}" }
        .to have_enqueued_job(SyncDeviceTopicsJob).with(device.id, topic_ids: [ topic.id ])
      expect(TopicSubscription.count).to eq(0)
    end
  end

  it "redirects to login when not signed in" do
    get "/admin/topics"
    expect(response).to redirect_to("/admin/login")
  end
end
