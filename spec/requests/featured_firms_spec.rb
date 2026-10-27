require "rails_helper"

RSpec.describe "Featured firms", type: :request do
  def feature(firm, starts_at: 1.hour.ago, ends_at: 1.day.from_now, position: 0)
    FeaturedPlacement.create!(firm:, starts_at:, ends_at:, position:)
  end

  it "serves current placements of visible firms, in order" do
    second = create(:firm, name: "Second")
    first = create(:firm, name: "First")
    feature(second, position: 2)
    feature(first, position: 1)
    feature(create(:firm, name: "Scheduled"), starts_at: 1.day.from_now, ends_at: 2.days.from_now)
    feature(create(:firm, name: "Ended"), starts_at: 2.days.ago, ends_at: 1.day.ago)
    feature(create(:firm, :pending, name: "Hidden"))

    get "/api/v1/firms/featured"

    expect(response).to have_http_status(:ok)
    expect(json["data"].map { _1["name"] }).to eq(%w[First Second])
  end

  it "lets a super admin feature a firm and cancel it, audited" do
    sign_in_admin
    firm = create(:firm)

    post "/admin/firms/#{firm.id}/featured_placements",
         params: { featured_placement: { starts_at: 1.minute.ago, ends_at: 7.days.from_now, position: 0, note: "افتتاح" } }

    placement = firm.featured_placements.last
    expect(placement.note).to eq("افتتاح")
    expect(PaperTrail::Version.last.operation).to eq("featured_placement.feature")

    get "/admin/featured_placements"
    expect(response.body).to include(firm.name)

    delete "/admin/featured_placements/#{placement.id}"
    expect(FeaturedPlacement.exists?(placement.id)).to be(false)
  end

  it "rejects a period that ends before it starts" do
    sign_in_admin
    firm = create(:firm)

    post "/admin/firms/#{firm.id}/featured_placements",
         params: { featured_placement: { starts_at: 1.day.from_now, ends_at: 1.hour.from_now } }

    expect(flash[:alert]).to be_present
    expect(firm.featured_placements).to be_empty
  end
end
