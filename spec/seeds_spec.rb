require "rails_helper"

RSpec.describe "db/seeds.rb" do
  around do |example|
    previous = ENV["SEED_DEMO"]
    ENV["SEED_DEMO"] = "1"
    example.run
  ensure
    ENV["SEED_DEMO"] = previous
  end

  def seed!
    expect { Rails.application.load_seed }.to output.to_stdout
  end

  it "imports the demo firms as visible listings" do
    seed!

    expect(Firm.visible.count).to eq(79)
    Category.where.not(name: [ "مواصلات" ]).find_each do |category|
      expect(Firm.visible.where(category:)).to exist, "no visible firm in #{category.name}"
    end
    expect(Firm.pending).to be_empty
    expect(Firm.suspended).to be_empty
  end

  it "keeps the welcome announcement" do
    seed!

    expect(Article.count).to eq(1)
    expect(Article.published).to contain_exactly(Article.find_by!(title: "مرحباً بكم في تطبيق أجهور الكبرى"))
    expect(Article.first).to be_announcement
  end

  it "does not create fictional subscriptions" do
    seed!

    expect(Subscription).to be_empty
  end

  it "imports the real places from Google Maps" do
    seed!

    real = Firm.where("description LIKE ?", "%خرائط جوجل%")
    expect(real.count).to eq(79)
    expect(real.active.count).to eq(79)
    expect(real.pending).to be_empty
    expect(real.suspended).to be_empty
    expect(real.distinct.pluck(:owner_id)).to eq([ User.super_admin.first.id ])

    pharmacy = Firm.find_by!(name: "صيدليات العمري [ اجهور الكبري ]")
    expect(pharmacy.category.name).to eq("صيدليات")
    expect(pharmacy.phone).to eq("01008501029")
    expect(pharmacy.address).to eq("أول شارع الشكارة، أجهور الكبرى، طوخ، القليوبية")
    expect(pharmacy.latitude).to eq(BigDecimal("30.298964"))
  end

  it "is idempotent" do
    seed!
    counts = [ User.count, Firm.count, Article.count, Subscription.count, Category.count, ActiveStorage::Attachment.count, FeatureFlag.count ]

    seed!

    expect([ User.count, Firm.count, Article.count, Subscription.count, Category.count, ActiveStorage::Attachment.count, FeatureFlag.count ]).to eq(counts)
  end

  it "seeds the plans flag off, and keeps a flag switched on from the dashboard on" do
    seed!
    expect(FeatureFlag.find_by!(key: "plans").enabled).to be(false)

    FeatureFlag.find_by!(key: "plans").update!(enabled: true)
    seed!

    expect(FeatureFlag.find_by!(key: "plans").enabled).to be(true)
  end

  it "attaches the default icon image to every seeded category" do
    seed!

    expect(Category.count).to eq(11)
    Category.find_each do |category|
      expect(category.icon_image).to be_attached, "#{category.name} has no icon image"
      expect(category.icon_image.filename.to_s).to eq("#{category.icon}.png")
    end
  end

  it "seeds the everyone topic and a public news topic, once" do
    seed!
    seed!

    expect(Topic.pluck(:key)).to contain_exactly("all", "news")
    expect(Topic.find_by!(key: "all")).to have_attributes(system: true, public: false)
    expect(Topic.find_by!(key: "news")).to have_attributes(system: false, public: true)
  end
end
