require "rails_helper"

RSpec.describe "Admin filter UI", type: :request do
  before { sign_in_admin }

  def doc = Nokogiri::HTML(response.body)

  describe "advanced filter panel" do
    it "offers fields that submit under f" do
      get "/admin/firms"

      panel = doc.at_css("details.adv-filter")
      expect(panel).to be_present
      expect(panel.at_css("input[name='f[owner_phone_start]']")).to be_present
    end

    it "is collapsed until a filter is in use" do
      get "/admin/firms"
      expect(doc.at_css("details.adv-filter")["open"]).to be_nil

      get "/admin/firms", params: { f: { owner_phone_start: "010" } }
      expect(doc.at_css("details.adv-filter")["open"]).not_to be_nil
    end

    it "is not opened by a sort alone" do
      get "/admin/firms", params: { f: { s: "name asc" } }

      expect(doc.at_css("details.adv-filter")["open"]).to be_nil
    end

    it "keeps the text search and status tab when the panel is submitted" do
      get "/admin/firms", params: { q: "صيدلية", status: "active" }

      form = doc.at_css("details.adv-filter form")
      expect(form.at_css("input[type=hidden][name='q']")["value"]).to eq("صيدلية")
      expect(form.at_css("input[type=hidden][name='status']")["value"]).to eq("active")
    end

    it "is on every admin index" do
      %w[ firms subscriptions users articles categories subscription_plans notifications ].each do |path|
        get "/admin/#{path}"
        expect(doc.at_css("details.adv-filter")).to be_present, "no filter panel on /admin/#{path}"
      end
    end
  end

  describe "sortable headers" do
    # The table, and so its header, only renders when there are rows.
    before { create(:firm, name: "صيدلية الشفاء") }

    it "link to a sort that keeps the current search" do
      get "/admin/firms", params: { q: "صيدلية" }

      link = doc.at_css("th a[href*='name']")
      expect(link).to be_present
      expect(CGI.unescape(link["href"])).to include("f[s]=name")
      expect(CGI.unescape(link["href"])).to include("q=صيدلية")
    end

    it "mark the sorted column for assistive technology" do
      get "/admin/firms", params: { f: { s: "name desc" } }

      expect(doc.at_css("th[aria-sort='descending']")).to be_present
    end

    # Ransack rebuilds these links from the request's params; a crafted host must not leak in.
    it "stay on this site under a crafted host param" do
      get "/admin/firms", params: { host: "evil.example.com" }

      hrefs = doc.css("th a").map { |a| a["href"] }
      expect(hrefs).to be_present
      expect(hrefs).to all(start_with("/admin/firms"))
    end
  end
end
