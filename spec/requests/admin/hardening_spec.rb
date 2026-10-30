require "rails_helper"

RSpec.describe "Admin hardening", type: :request do
  before { sign_in_admin }

  def doc = Nokogiri::HTML(response.body)

  describe "filter links" do
    it "does not let a query parameter send tab links off-site" do
      get "/admin/firms", params: { host: "evil.example.com" }

      hrefs = doc.css(".tabs .tab").map { |tab| tab["href"] }
      expect(hrefs).to be_present
      expect(hrefs).to all(start_with("/admin/firms"))
    end

    it "does not let a query parameter reroute pagination links" do
      create_list(:category, 2).each { |category| create(:firm, category: category) }

      get "/admin/firms", params: { host: "evil.example.com", per_page: 1 }
      hrefs = doc.css(".pagination a[href]").map { |link| link["href"] }
      expect(hrefs).to be_present
      expect(hrefs).to all(start_with("/admin/firms"))
    end

    it "ignores a crafted controller parameter instead of raising" do
      get "/admin/firms", params: { controller: "admin/users" }
      expect(response).to have_http_status(:ok)
      expect(doc.css(".tabs .tab").map { |tab| tab["href"] }).to all(start_with("/admin/firms"))
    end
  end

  describe "state that used to be words" do
    it "gives the visibility switch an accessible name" do
      create(:firm)
      get "/admin/firms"

      switch = doc.at_css("tbody .switch")
      expect(switch).to be_present
      expect(switch["aria-label"]).to be_present
    end

    it "marks the active filter tab for assistive technology" do
      get "/admin/firms", params: { status: "active" }

      current = doc.css(".tabs .tab").select { |tab| tab["aria-current"] == "page" }
      expect(current.map { |tab| tab.text.strip }).to eq([ "مفعّلة" ])
    end
  end

  describe "vocabulary" do
    it "confirms a firm approval in the new vocabulary" do
      firm = create(:firm, :pending)
      patch "/admin/firms/#{firm.id}/approve"

      expect(flash[:notice]).to include("النشاط")
      expect(flash[:notice]).not_to include("المنشأة")
    end

    it "confirms a category creation in the new vocabulary" do
      post "/admin/categories", params: { category: { name: "تصنيف جديد" } }

      expect(flash[:notice]).to include("التصنيف")
      expect(flash[:notice]).not_to include("القسم")
    end
  end
end
