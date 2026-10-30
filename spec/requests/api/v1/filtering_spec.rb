require "rails_helper"

# Structured filters arrive under `f[...]` (ransack); `q` stays the plain-text search the shipped
# Android app already sends. The public tier may only filter on what the response already shows.
RSpec.describe "API filtering", type: :request do
  def ids = json["data"].map { |row| row["id"] }

  describe "firms (public)" do
    it "filters by a field the response already shows" do
      category = create(:category)
      wanted = create(:firm, category:)
      create(:firm)

      get "/api/v1/firms", params: { f: { category_id_eq: category.id } }

      expect(ids).to eq([ wanted.id ])
    end

    it "matches part of a name" do
      wanted = create(:firm, name: "صيدلية الشفاء")
      create(:firm, name: "مطعم الريف")

      get "/api/v1/firms", params: { f: { name_cont: "الشفاء" } }

      expect(ids).to eq([ wanted.id ])
    end

    # The leak this design exists to prevent: filtering on a field the caller cannot see turns
    # the result set into an oracle. A disallowed condition is ignored, so nothing is narrowed.
    it "ignores a filter on the owner's phone" do
      owner = create(:user, :subscribed, phone: "01011112222")
      create(:firm, owner:)
      bystander = create(:firm)

      get "/api/v1/firms", params: { f: { owner_phone_start: "0101111" } }

      expect(ids).to include(bystander.id)
    end

    it "ignores a filter that reaches payment data through the owner" do
      bystander = create(:firm)

      get "/api/v1/firms", params: { f: { owner_subscriptions_transaction_reference_eq: "TX-1" } }

      expect(ids).to include(bystander.id)
    end

    it "cannot widen beyond the policy scope" do
      hidden = create(:firm, :pending)

      get "/api/v1/firms", params: { f: { status_eq: Firm.statuses[:pending] } }

      expect(ids).not_to include(hidden.id)
    end

    it "keeps the old plain-text q search working for shipped apps" do
      wanted = create(:firm, name: "صيدلية الشفاء")
      create(:firm, name: "مطعم الريف")

      get "/api/v1/firms", params: { q: "الشفاء" }

      expect(ids).to eq([ wanted.id ])
    end

    it "combines q with f" do
      category = create(:category)
      wanted = create(:firm, name: "صيدلية الشفاء", category:)
      create(:firm, name: "صيدلية النور")

      get "/api/v1/firms", params: { q: "صيدلية", f: { category_id_eq: category.id } }

      expect(ids).to eq([ wanted.id ])
    end

    it "sorts by an allowlisted field" do
      create(:firm, name: "ب")
      create(:firm, name: "أ")

      get "/api/v1/firms", params: { f: { s: "name desc" } }

      expect(json["data"].map { |row| row["name"] }).to eq([ "ب", "أ" ])
    end
  end

  describe "subscriptions (own rows only)" do
    it "lets a user filter their own subscriptions by reference" do
      user = create(:user)
      # one pending subscription per user is a DB-backed rule, so these are settled ones
      wanted = create(:subscription, :current, user:, transaction_reference: "TX-WANTED")
      create(:subscription, :expired, user:, transaction_reference: "TX-OTHER")

      get "/api/v1/subscriptions", params: { f: { transaction_reference_eq: "TX-WANTED" } },
                                   headers: auth_headers(user)

      expect(ids).to eq([ wanted.id ])
    end

    it "never returns another user's subscription, whatever the filter" do
      user = create(:user)
      other = create(:subscription, transaction_reference: "TX-THEIRS")

      get "/api/v1/subscriptions", params: { f: { transaction_reference_eq: "TX-THEIRS" } },
                                   headers: auth_headers(user)

      expect(ids).not_to include(other.id)
    end
  end

  describe "articles (public)" do
    it "filters by kind" do
      wanted = create(:article, kind: :announcement)
      create(:article, kind: :news)

      get "/api/v1/articles", params: { f: { kind_eq: Article.kinds[:announcement] } }

      expect(ids).to eq([ wanted.id ])
    end

    # author leads to a User, and through it to a phone number.
    it "ignores a filter on the author's phone" do
      bystander = create(:article)

      get "/api/v1/articles", params: { f: { author_phone_start: "010" } }

      expect(ids).to include(bystander.id)
    end
  end

  describe "categories and plans (public)" do
    it "filters categories by name" do
      wanted = create(:category, name: "صيدليات")
      create(:category, name: "مطاعم")

      get "/api/v1/categories", params: { f: { name_cont: "صيد" } }

      expect(ids).to eq([ wanted.id ])
    end

    it "filters plans by a price range" do
      cheap = create(:subscription_plan, price_cents: 5_000)
      create(:subscription_plan, price_cents: 50_000)

      get "/api/v1/subscription_plans", params: { f: { price_cents_lteq: 10_000 } }

      expect(ids).to eq([ cheap.id ])
    end
  end

  describe "notifications (own rows only)" do
    it "filters the caller's own notifications by kind" do
      user = create(:user)
      wanted = Notification.create!(user:, kind: :subscription_expired, title: "ت", body: "ب")
      Notification.create!(user:, kind: :subscription_approved, title: "ت", body: "ب")

      get "/api/v1/notifications", params: { f: { kind_eq: Notification.kinds[:subscription_expired] } },
                                   headers: auth_headers(user)

      expect(ids).to eq([ wanted.id ])
    end
  end

  describe "admin API (admin tier)" do
    let(:admin) { create(:user, :super_admin) }

    it "lets a super admin filter users by phone" do
      wanted = create(:user, phone: "01077778888")
      create(:user, phone: "01099990000")

      get "/api/v1/admin/users", params: { f: { phone_start: "0107777" } }, headers: auth_headers(admin)

      expect(ids).to eq([ wanted.id ])
    end

    it "lets a super admin find a payment by reference across users" do
      wanted = create(:subscription, transaction_reference: "TX-FIND-ME")
      create(:subscription, transaction_reference: "TX-NOT-ME")

      get "/api/v1/admin/subscriptions", params: { f: { transaction_reference_eq: "TX-FIND-ME" } },
                                         headers: auth_headers(admin)

      expect(ids).to eq([ wanted.id ])
    end

    it "does not grant the admin tier to an ordinary user" do
      get "/api/v1/admin/users", params: { f: { phone_start: "010" } }, headers: auth_headers(create(:user))

      expect(response).to have_http_status(:forbidden)
    end
  end
end
