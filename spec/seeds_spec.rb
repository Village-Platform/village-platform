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

  it "creates demo firms that are visible in every category" do
    seed!

    expect(Firm.visible.count).to be >= 15
    Category.find_each do |category|
      expect(Firm.visible.where(category:)).to exist, "no visible firm in #{category.name}"
    end
    expect(Firm.pending).to exist
    expect(Firm.suspended).to exist
  end

  it "creates news of every kind, a draft and a scheduled post" do
    seed!

    expect(Article.published.distinct.pluck(:kind)).to match_array(%w[news article announcement])
    expect(Article.where(published_at: nil)).to exist
    expect(Article.where(published_at: Time.current..)).to exist
  end

  it "creates subscriptions for the dashboard: current, expiring soon, pending and rejected" do
    seed!

    expect(Subscription.current.count).to be >= 10
    expect(Subscription.current.where(ends_at: ..7.days.from_now)).to exist
    expect(Subscription.pending).to exist
    expect(Subscription.rejected).to exist
  end

  it "is idempotent" do
    seed!
    counts = [ User.count, Firm.count, Article.count, Subscription.count, Category.count ]

    seed!

    expect([ User.count, Firm.count, Article.count, Subscription.count, Category.count ]).to eq(counts)
  end
end
