require "rails_helper"

RSpec.describe "Subscriber articles", type: :request do
  let(:plan) { create(:subscription_plan, max_articles_per_month: 2) }
  let(:author) { create(:user, :firm_admin).tap { |u| create(:subscription, :current, user: u, subscription_plan: plan) } }
  let(:super_admin) { create(:user, :super_admin) }

  def submit(as: author, **attrs)
    post "/api/v1/articles", params: { article: { title: "عرض", body: "خصم", kind: "news", **attrs } },
                             headers: auth_headers(as)
  end

  it "keeps a subscriber's article pending and out of the public feed until approved" do
    submit

    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("review_state" => "pending", "published_at" => nil)
    article = Article.find(json["data"]["id"])

    get "/api/v1/articles"
    expect(json["data"]).to be_empty

    patch "/api/v1/admin/articles/#{article.id}/approve", headers: auth_headers(super_admin)
    expect(json["data"]["review_state"]).to eq("approved")
    expect(author.notifications.last.kind).to eq("article_approved")
    expect(AuditEvent.last.action).to eq("article.approve")

    get "/api/v1/articles"
    expect(json["data"].map { _1["id"] }).to eq([ article.id ])
  end

  it "shows the author every state and the rejection reason" do
    submit
    patch "/api/v1/admin/articles/#{json['data']['id']}/reject", params: { reason: "مخالف" }, headers: auth_headers(super_admin)

    get "/api/v1/me/articles", headers: auth_headers(author)

    expect(json["data"].first).to include("review_state" => "rejected", "rejection_reason" => "مخالف")
    expect(author.notifications.last.kind).to eq("article_rejected")
  end

  it "enforces the monthly quota" do
    2.times { submit }
    submit

    expect(response).to have_http_status(:forbidden)
    expect(json["error"]["code"]).to eq("media_limit_reached")
  end

  it "does not let a subscriber publish directly, write announcements or tag someone else's firm" do
    submit(published_at: 1.day.ago.iso8601)
    expect(json["data"]["published_at"]).to be_nil

    submit(kind: "announcement")
    expect(response).to have_http_status(:forbidden)

    submit(firm_id: create(:firm).id)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "sends an edited approved article back to review" do
    article = create(:article, author:, review_state: :approved)

    patch "/api/v1/articles/#{article.id}", params: { article: { body: "نص جديد" } }, headers: auth_headers(author)

    expect(article.reload).to have_attributes(review_state: "pending", published_at: nil)
  end

  it "hides an approved article once the author's subscription has expired" do
    expired = create(:user, :firm_admin).tap { |u| create(:subscription, :expired, user: u) }
    create(:article, author: expired)

    get "/api/v1/articles"

    expect(json["data"]).to be_empty
  end

  it "attaches an optimized cover image" do
    post "/api/v1/articles",
         params: { article: { title: "صورة", body: "x" }, cover_image: fixture_file_upload("photo_with_gps.jpg", "image/jpeg") },
         headers: auth_headers(author)

    expect(response).to have_http_status(:created)
    expect(Article.last.cover_image.blob.content_type).to eq("image/webp")
    expect(json["data"]["cover_image_url"]).to be_present
  end

  describe "dashboard" do
    it "lists pending articles and approves or rejects them" do
      sign_in_admin
      pending_one = create(:article, author:, review_state: :pending, published_at: nil)
      other = create(:article, author:, review_state: :pending, published_at: nil)

      get "/admin/articles", params: { review_state: "pending" }
      expect(response.body).to include(pending_one.title)

      patch "/admin/articles/#{pending_one.id}/approve"
      expect(pending_one.reload).to be_approved

      patch "/admin/articles/#{other.id}/reject", params: { reason: "" }
      expect(other.reload).to be_pending

      patch "/admin/articles/#{other.id}/reject", params: { reason: "مكرر" }
      expect(other.reload).to have_attributes(review_state: "rejected", rejection_reason: "مكرر")
    end
  end
end
