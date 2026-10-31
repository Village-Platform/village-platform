require "rails_helper"

# `meta` is read by Android versions already in the field, so its shape and edge cases are pinned
# here independently of the library behind `paginate`.
RSpec.describe "Pagination", type: :request do
  describe "API meta" do
    before { create_list(:category, 3) }

    def meta_for(params)
      get "/api/v1/categories", params: params
      json["meta"]
    end

    it "keeps its four keys" do
      expect(meta_for(per_page: 2)).to eq("page" => 1, "per_page" => 2, "total" => 3, "total_pages" => 2)
    end

    it "returns the requested page" do
      get "/api/v1/categories", params: { per_page: 2, page: 2 }

      expect(json["data"].size).to eq(1)
      expect(json["meta"]).to include("page" => 2)
    end

    it "caps per_page at 100" do
      expect(meta_for(per_page: 999)).to include("per_page" => 100)
    end

    it "clamps a per_page of zero, below zero or garbage to 1" do
      expect(meta_for(per_page: 0)).to include("per_page" => 1)
      expect(meta_for(per_page: -5)).to include("per_page" => 1)
      expect(meta_for(per_page: "abc")).to include("per_page" => 1)
    end

    it "treats a page below 1 as page 1" do
      expect(meta_for(page: -3)).to include("page" => 1)
    end

    it "answers a page past the end with an empty list" do
      get "/api/v1/categories", params: { per_page: 2, page: 9 }

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to eq([])
      expect(json["meta"]).to include("page" => 9, "total" => 3)
    end

    it "reports 0 pages for an empty list" do
      Category.delete_all

      expect(meta_for({})).to include("total" => 0, "total_pages" => 0)
    end
  end

  describe "admin pager" do
    before do
      sign_in_admin
      create_list(:firm, 3, name: "صيدلية")
    end

    def doc = Nokogiri::HTML(response.body)
    def page_links = doc.css(".pagination a[href]").map { |a| CGI.unescape(a["href"]) }

    it "numbers the pages and marks the current one" do
      get "/admin/firms", params: { per_page: 1, page: 2 }

      expect(doc.at_css(".pagination a[aria-current='page']").text).to eq("2")
      expect(page_links).to include(a_string_including("page=3"))
    end

    it "keeps the advanced filters and sort on every page link" do
      get "/admin/firms", params: { per_page: 1, q: "صيدلية", f: { name_cont: "صيدلية", s: "name desc" } }

      expect(page_links).to be_present
      expect(page_links).to all(include("f[name_cont]=صيدلية", "f[s]=name desc", "q=صيدلية", "per_page=1"))
    end

    it "is hidden when everything fits on one page" do
      get "/admin/firms"

      expect(doc.at_css(".pagination")).to be_nil
    end
  end
end
