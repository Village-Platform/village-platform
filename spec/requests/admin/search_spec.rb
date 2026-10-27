require "rails_helper"

RSpec.describe "Admin global search", type: :request do
  describe "without a session" do
    it "redirects to login and returns no data" do
      get "/admin/search", params: { q: "anything" }

      expect(response).to redirect_to("/admin/login")
      expect(response.body).not_to include("title")
    end
  end

  describe "signed in" do
    before { sign_in_admin }

    it "returns nothing below the minimum query length" do
      create(:firm, name: "صيدلية الشفاء")

      get "/admin/search", params: { q: "صي" }

      expect(response).to have_http_status(:ok)
      expect(json).to eq([])
    end

    it "finds a firm by name and links to its page" do
      firm = create(:firm, name: "صيدلية الشفاء")

      get "/admin/search", params: { q: "الشفاء" }

      result = json.find { |row| row["title"] == firm.name }
      expect(result).to be_present
      expect(result["type"]).to eq("نشاط")
      expect(result["url"]).to eq("/admin/firms/#{firm.id}")
    end

    it "finds a user by phone" do
      user = create(:user, name: "ليلى ناصر", phone: "01099887766")

      get "/admin/search", params: { q: "9988" }

      expect(json.map { |row| row["title"] }).to include(user.name)
    end

    it "matches case-insensitively on latin text" do
      firm = create(:firm, name: "Noor Pharmacy")

      get "/admin/search", params: { q: "noor" }

      expect(json.map { |row| row["title"] }).to include(firm.name)
    end

    it "limits a scoped search to that type" do
      create(:firm, name: "مطعم الريف")
      create(:category, name: "مطاعم الريف")

      get "/admin/search", params: { q: "الريف", scope: "categories" }

      expect(json.map { |row| row["type"] }.uniq).to eq([ "تصنيف" ])
    end

    it "returns a deeper list when scoped to a single type" do
      category = create(:category)
      owner = create(:user, :subscribed)
      9.times { |i| create(:firm, category:, owner:, name: "صيدلية رقم #{i}") }

      get "/admin/search", params: { q: "صيدلية", scope: "firms" }

      expect(json.size).to eq(8)
    end

    it "keeps the global dropdown shallow so every type can show" do
      category = create(:category)
      owner = create(:user, :subscribed)
      9.times { |i| create(:firm, category:, owner:, name: "صيدلية رقم #{i}") }

      get "/admin/search", params: { q: "صيدلية" }

      expect(json.size).to eq(4)
    end

    it "ignores an unknown scope rather than searching everything" do
      create(:firm, name: "مطعم الريف")

      get "/admin/search", params: { q: "الريف", scope: "../../etc/passwd" }

      expect(response).to have_http_status(:ok)
      expect(json).to eq([])
    end
  end
end
