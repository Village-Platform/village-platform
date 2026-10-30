require "rails_helper"

# Admin gets the admin allowlist tier: it may filter and sort on fields the public API may not,
# including traversals into users. The existing text box (`q`) and status tabs keep working, and
# `f[...]` composes on top of them.
RSpec.describe "Admin filtering", type: :request do
  before { sign_in_admin }

  def body = response.body

  describe "firms" do
    it "filters by the owner's phone, which only the admin tier allows" do
      owner = create(:user, :subscribed, phone: "01055556666")
      create(:firm, owner:, name: "صيدلية المالك")
      create(:firm, name: "مطعم آخر")

      get "/admin/firms", params: { f: { owner_phone_start: "0105555" } }

      expect(body).to include("صيدلية المالك")
      expect(body).not_to include("مطعم آخر")
    end

    it "keeps the text box working alongside f" do
      category = create(:category)
      create(:firm, name: "صيدلية الشفاء", category:)
      create(:firm, name: "صيدلية النور")

      get "/admin/firms", params: { q: "صيدلية", f: { category_id_eq: category.id } }

      expect(body).to include("صيدلية الشفاء")
      expect(body).not_to include("صيدلية النور")
    end

    # The index defaults to newest first, so "أ" is created first: only the requested sort can
    # bring it to the top. Created the other way round, this would pass without sorting at all.
    it "sorts by a column" do
      create(:firm, name: "أ-نشاط")
      create(:firm, name: "ب-نشاط")

      get "/admin/firms", params: { f: { s: "name asc" } }

      expect(body.index("أ-نشاط")).to be < body.index("ب-نشاط")
    end
  end

  describe "subscriptions" do
    it "filters by a creation date range" do
      create(:subscription, transaction_reference: "TX-OLD", created_at: 40.days.ago)
      create(:subscription, transaction_reference: "TX-NEW")

      get "/admin/subscriptions", params: { f: { created_at_gteq: 7.days.ago.to_date.iso8601 } }

      expect(body).to include("TX-NEW")
      expect(body).not_to include("TX-OLD")
    end

    it "filters by an amount range" do
      create(:subscription, transaction_reference: "TX-SMALL", amount_cents: 5_000)
      create(:subscription, transaction_reference: "TX-LARGE", amount_cents: 90_000)

      get "/admin/subscriptions", params: { f: { amount_cents_gteq: 50_000 } }

      expect(body).to include("TX-LARGE")
      expect(body).not_to include("TX-SMALL")
    end
  end

  describe "articles" do
    it "filters by author name, an admin-only traversal" do
      author = create(:user, :super_admin, name: "كاتب المقالات")
      create(:article, author:, title: "مقال الكاتب")
      create(:article, title: "مقال آخر")

      get "/admin/articles", params: { f: { author_name_cont: "كاتب" } }

      expect(body).to include("مقال الكاتب")
      expect(body).not_to include("مقال آخر")
    end
  end

  describe "users" do
    it "filters by role and phone together" do
      create(:user, :firm_admin, name: "صاحب نشاط", phone: "01033334444")
      create(:user, name: "مقيم", phone: "01033335555")

      get "/admin/users", params: { f: { role_eq: User.roles[:firm_admin], phone_start: "0103333" } }

      expect(body).to include("صاحب نشاط")
      expect(body).not_to include("مقيم")
    end
  end

  describe "categories, plans and notifications" do
    it "filters categories by name" do
      create(:category, name: "صيدليات")
      create(:category, name: "مطاعم")

      get "/admin/categories", params: { f: { name_cont: "صيد" } }

      expect(body).to include("صيدليات")
      expect(body).not_to include("مطاعم")
    end

    it "filters plans by duration" do
      create(:subscription_plan, name: "باقة شهرية", duration_days: 30)
      create(:subscription_plan, name: "باقة سنوية", duration_days: 365)

      get "/admin/subscription_plans", params: { f: { duration_days_gteq: 300 } }

      expect(body).to include("باقة سنوية")
      expect(body).not_to include("باقة شهرية")
    end

    it "filters notifications by recipient phone" do
      wanted = create(:user, phone: "01022223333")
      Notification.create!(user: wanted, kind: :subscription_expired, title: "إشعار مطلوب", body: "ب")
      Notification.create!(user: create(:user), kind: :subscription_expired, title: "إشعار آخر", body: "ب")

      get "/admin/notifications", params: { f: { user_phone_start: "0102222" } }

      expect(body).to include("إشعار مطلوب")
      expect(body).not_to include("إشعار آخر")
    end
  end
end
