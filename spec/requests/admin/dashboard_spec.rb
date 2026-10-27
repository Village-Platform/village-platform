require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  before { sign_in_admin }

  it "renders the four stat tiles" do
    get "/admin"
    [ "إجمالي الأهالي", "الأنشطة المسجلة", "الاشتراكات الفعالة", "المقالات المنشورة" ].each do |label|
      expect(response.body).to include(label)
    end
  end

  it "renders the action card" do
    get "/admin"
    expect(response.body).to include("تحتاج إجراءك")
  end

  it "counts visible firms per category" do
    firm = create(:firm)
    create(:firm, category: firm.category, owner: firm.owner)

    get "/admin"
    bars = Nokogiri::HTML(response.body).at_css(".bars")
    expect(bars).to be_present
    row = bars.css(".bar-row").find { |r| r.at_css(".bar-head span").text == firm.category.name }
    expect(row).to be_present
    expect(row.at_css(".bar-head b").text).to eq("2")
  end

  it "renders without raising when there are no firms at all" do
    get "/admin"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("لا توجد أنشطة بعد")
  end

  it "does not render a revenue tile" do
    get "/admin"
    expect(response.body).not_to include("الإيرادات")
  end
end
