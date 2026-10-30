require "rails_helper"

RSpec.describe "Admin article auto-push", type: :request do
  include ActiveJob::TestHelper

  before { sign_in_admin }

  let(:news) { create(:topic, :listed, key: "news") }

  def create_article(**attrs)
    post "/admin/articles", params: { article: { title: "افتتاح المدرسة", body: "نص طويل " * 40, kind: "news", **attrs } }
    Article.last
  end

  def local(time) = time.strftime("%Y-%m-%dT%H:%M")

  it "schedules a campaign for now when published now with a topic" do
    freeze_time do
      article = nil
      expect { article = create_article(published_at: local(Time.current), notify_topic_id: news.id) }
        .to have_enqueued_job(DeliverCampaignJob)

      campaign = article.push_campaign
      expect(campaign).to have_attributes(screen: "article", target_id: article.id, title: "افتتاح المدرسة", status: "scheduled")
      expect(campaign.body.length).to be <= 140
      expect(campaign.topics).to eq([ news ])
      expect(campaign.scheduled_at).to be_within(1.minute).of(Time.current)
    end
  end

  it "schedules for a future published_at" do
    at = 3.days.from_now.change(sec: 0)
    article = create_article(published_at: local(at), notify_topic_id: news.id)
    expect(article.push_campaign.scheduled_at).to eq(at)
  end

  it "reschedules when published_at moves" do
    article = create_article(published_at: local(2.days.from_now), notify_topic_id: news.id)
    later = 5.days.from_now.change(sec: 0)

    expect { patch "/admin/articles/#{article.id}", params: { article: { published_at: local(later) } } }
      .to have_enqueued_job(DeliverCampaignJob).at(later)
    expect(article.push_campaign.reload.scheduled_at).to eq(later)
  end

  it "does not queue a second delivery when only the topic changes" do
    article = create_article(published_at: local(2.days.from_now), notify_topic_id: news.id)
    owners = create(:topic, key: "owners")

    expect { patch "/admin/articles/#{article.id}", params: { article: { notify_topic_id: owners.id } } }
      .not_to have_enqueued_job(DeliverCampaignJob)
    expect(article.push_campaign.reload.topics).to eq([ owners ])
  end

  it "cancels when the topic is cleared" do
    article = create_article(published_at: local(2.days.from_now), notify_topic_id: news.id)
    patch "/admin/articles/#{article.id}", params: { article: { notify_topic_id: "" } }
    expect(article.push_campaign.reload).to be_canceled
  end

  it "cancels when the article goes back to draft" do
    article = create_article(published_at: local(2.days.from_now), notify_topic_id: news.id)
    patch "/admin/articles/#{article.id}", params: { article: { published_at: "" } }
    expect(article.push_campaign.reload).to be_canceled
  end

  it "never re-pushes after the campaign was sent" do
    article = create_article(published_at: local(1.hour.ago), notify_topic_id: news.id)
    article.push_campaign.update_columns(status: NotificationCampaign.statuses[:sent])

    expect { patch "/admin/articles/#{article.id}", params: { article: { title: "عنوان جديد", published_at: local(Time.current) } } }
      .not_to have_enqueued_job(DeliverCampaignJob)
    expect(NotificationCampaign.count).to eq(1)
  end

  it "creates nothing for a draft or without a topic" do
    create_article(published_at: "", notify_topic_id: news.id)
    create_article(published_at: local(Time.current))
    expect(NotificationCampaign.count).to eq(0)
  end

  it "lets the article be fully deleted after its campaign" do
    article = create_article(published_at: local(1.hour.ago), notify_topic_id: news.id)
    article.destroy
    delete "/admin/articles/#{article.id}/destroy_fully"
    expect(Article.with_deleted.exists?(article.id)).to be(false)
    expect(NotificationCampaign.sole.article_id).to be_nil
  end

  it "offers the topics on the form" do
    news
    get "/admin/articles/new"
    expect(response.body).to include("article[notify_topic_id]")
  end
end
