require "rails_helper"

RSpec.describe "Admin listings", type: :request do
  before { sign_in_admin }

  def doc = Nokogiri::HTML(response.body)

  it "titles the firms index with the design's vocabulary" do
    get "/admin/firms"
    expect(doc.at_css(".topbar h1").text.strip).to eq("الأنشطة")
  end

  it "renders the firm status filter as a tab row with the active one marked" do
    get "/admin/firms", params: { status: "active" }
    tabs = doc.css(".tabs .tab")
    expect(tabs.map { |t| t.text.strip }).to include("الكل", "قيد المراجعة", "مفعّلة", "موقوفة")
    expect(tabs.select { |t| t["class"].include?("tab-on") }.map { |t| t.text.strip }).to eq([ "مفعّلة" ])
  end

  it "keeps the other filters when a status tab is followed" do
    get "/admin/firms", params: { q: "zayed" }
    href = doc.css(".tabs .tab").last["href"]
    expect(href).to include("q=zayed")
  end

  it "shows public visibility as a switch" do
    create(:firm)
    get "/admin/firms"
    expect(doc.at_css("tbody .switch")).to be_present
  end

  it "renders the subscription status filter as a tab row" do
    get "/admin/subscriptions"
    expect(doc.css(".tabs .tab").map { |t| t.text.strip }).to include("الكل", "قيد المراجعة", "مقبول", "مرفوض")
  end

  it "titles the remaining indexes with the design's vocabulary" do
    { "/admin/categories" => "التصنيفات",
      "/admin/articles" => "الأخبار والمقالات",
      "/admin/subscription_plans" => "الباقات والأسعار" }.each do |path, title|
      get path
      expect(doc.at_css(".topbar h1").text.strip).to eq(title)
    end
  end

  it "renders the user role filter as a tab row" do
    get "/admin/users"
    expect(doc.css(".tabs .tab").map { |t| t.text.strip })
      .to include("الكل", "مستخدم", "صاحب منشأة", "مدير النظام")
  end

  it "renders the article kind filter as a tab row" do
    get "/admin/articles"
    expect(doc.css(".tabs .tab").map { |t| t.text.strip }).to include("الكل", "خبر", "مقال", "إعلان")
  end

  it "shows category and plan activation as switches" do
    create(:category)
    create(:subscription_plan)

    get "/admin/categories"
    expect(doc.at_css("tbody .switch")).to be_present

    get "/admin/subscription_plans"
    expect(doc.at_css("tbody .switch")).to be_present
  end
end
