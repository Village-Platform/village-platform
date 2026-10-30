require "rails_helper"

RSpec.describe "Admin notification campaigns", type: :request do
  include ActiveJob::TestHelper

  let!(:admin) { sign_in_admin }
  let(:news) { create(:topic, :listed, key: "news", name: "الأخبار") }
  let(:owners) { create(:topic, key: "owners", name: "أصحاب الأنشطة") }

  def create_campaign(**attrs)
    post "/admin/notification_campaigns", params: {
      notification_campaign: { title: "عرض", body: "تفاصيل", screen: "none", topic_ids: [ news.id ], **attrs }
    }
  end

  it "renders the form with topics and screens" do
    news
    get "/admin/notification_campaigns/new"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("الأخبار", "notification_campaign[screen]")
  end

  it "creates a scheduled campaign for two topics" do
    article = create(:article)
    at = 2.days.from_now.change(sec: 0)

    expect {
      create_campaign(topic_ids: [ news.id, owners.id ], screen: "article", target_id: article.id,
                      scheduled_at: at.strftime("%Y-%m-%dT%H:%M"))
    }.to have_enqueued_job(DeliverCampaignJob).at(at)

    campaign = NotificationCampaign.sole
    expect(response).to redirect_to("/admin/notification_campaigns/#{campaign.id}")
    expect(campaign).to have_attributes(status: "scheduled", screen: "article", target_id: article.id, created_by: admin)
    expect(campaign.topics).to contain_exactly(news, owners)
  end

  it "sends now when no time is given" do
    freeze_time do
      expect { create_campaign }.to have_enqueued_job(DeliverCampaignJob).at(Time.current)
    end
  end

  it "rejects six topics" do
    create_campaign(topic_ids: create_list(:topic, 6).map(&:id))
    expect(response).to have_http_status(:unprocessable_content)
    expect(NotificationCampaign.count).to eq(0)
  end

  it "rejects an article that does not exist" do
    create_campaign(screen: "article", target_id: 0)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("غير موجود")
  end

  it "shows the campaign with its target's title" do
    article = create(:article, title: "افتتاح المدرسة")
    create_campaign(screen: "article", target_id: article.id)
    get "/admin/notification_campaigns/#{NotificationCampaign.sole.id}"
    expect(response.body).to include("افتتاح المدرسة", "الأخبار")
  end

  it "lists campaigns" do
    create(:notification_campaign, title: "حملة الشتاء")
    get "/admin/notification_campaigns"
    expect(response.body).to include("حملة الشتاء")
  end

  it "cancels a scheduled campaign" do
    campaign = create(:notification_campaign, scheduled_at: 1.day.from_now)
    patch "/admin/notification_campaigns/#{campaign.id}/cancel"
    expect(campaign.reload).to be_canceled
  end

  it "cannot cancel a sent one" do
    campaign = create(:notification_campaign)
    campaign.update_columns(status: NotificationCampaign.statuses[:sent])
    patch "/admin/notification_campaigns/#{campaign.id}/cancel"
    expect(flash[:alert]).to be_present
    expect(campaign.reload).to be_sent
  end

  describe "single-user notifications" do
    let(:user) { create(:user) }

    it "stores the destination and pushes to each device" do
      article = create(:article)
      create_list(:device, 2, user:)

      expect {
        post "/admin/notifications", params: {
          notification: { user_id: user.id, title: "تنبيه", body: "نص", screen: "article", target_id: article.id }
        }
      }.to have_enqueued_job(PushNotificationJob).exactly(2).times

      expect(user.notifications.sole).to have_attributes(kind: "system_announcement", title: "تنبيه",
                                                         data: { "screen" => "article", "id" => article.id.to_s })
    end

    it "rejects an unknown destination" do
      post "/admin/notifications", params: {
        notification: { user_id: user.id, title: "تنبيه", body: "نص", screen: "firm", target_id: 0 }
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(Notification.count).to eq(0)
    end

    it "no longer sends to everyone from this form" do
      create_list(:user, 2)
      post "/admin/notifications", params: { target: "all", notification: { title: "تنبيه", body: "نص" } }

      expect(Notification.count).to eq(0)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
