require "rails_helper"

RSpec.describe "Tailwind build" do
  # Tailwind minifies: no space after the colon in a media query, no quotes in an
  # attribute selector. Compare against a whitespace-free copy so these examples
  # assert the cascade, not the formatter.
  let(:css) { Rails.root.join("app/assets/builds/tailwind.css").read }
  let(:compact) { css.gsub(/\s+/, "").delete('"') }

  it "defines the design tokens" do
    expect(css).to include("--color-gold")
    expect(css).to include("--color-surface2")
    expect(css).to include("--color-goldink")
  end

  it "defines both theme states" do
    expect(compact).to include("prefers-color-scheme:dark")
    expect(compact).to include(":root[data-theme=dark]")
  end

  it "keeps an explicit light choice from losing to a dark OS" do
    expect(compact).to include(":root:not([data-theme=light])")
  end

  it "omits preflight so admin.css still applies" do
    expect(css).not_to include("-webkit-text-size-adjust")
  end
end
