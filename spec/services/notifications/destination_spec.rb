require "rails_helper"

RSpec.describe Notifications::Destination do
  def destination(screen, id = nil) = described_class.new(screen:, id:)

  it "accepts a published article" do
    article = create(:article)
    expect(destination("article", article.id)).to be_valid
    expect(destination("article", article.id).target).to eq(article)
  end

  it "rejects a draft or deleted article" do
    expect(destination("article", create(:article, :draft).id)).not_to be_valid
    deleted = create(:article)
    deleted.destroy
    expect(destination("article", deleted.id)).not_to be_valid
    expect(destination("article", deleted.id).error).to be_present
  end

  it "rejects a firm that is not visible" do
    expect(destination("firm", create(:firm).id)).to be_valid
    expect(destination("firm", create(:firm, :pending).id)).not_to be_valid
  end

  it "accepts a category and a subscription" do
    expect(destination("category", create(:category).id)).to be_valid
    expect(destination("subscription", create(:subscription).id)).to be_valid
  end

  it "rejects an unknown screen and a missing id" do
    expect(destination("profile", 1)).not_to be_valid
    expect(destination("article")).not_to be_valid
  end

  it "accepts none without an id" do
    expect(described_class.none).to be_valid
    expect(described_class.none.to_data).to eq("screen" => "none")
  end

  it "serializes ids as strings" do
    expect(destination("article", 7).to_data).to eq("screen" => "article", "id" => "7")
  end

  it "offers admins every screen except subscription" do
    expect(described_class::ADMIN_SCREENS).to eq(%w[ none article firm category ])
  end
end
