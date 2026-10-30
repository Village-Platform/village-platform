require "rails_helper"

RSpec.describe Fcm::Message do
  it "stringifies data values" do
    message = described_class.build(target: { token: "t" }, title: "T", body: "B", data: { id: 42, screen: :article })
    expect(message[:data]).to eq("id" => "42", "screen" => "article")
    expect(message[:token]).to eq("t")
    expect(message[:notification]).to eq(title: "T", body: "B")
    expect(message.dig(:android, :priority)).to eq("high")
  end

  it "builds a condition for several topics" do
    expect(described_class.target_for_topics(%w[ news owners ]))
      .to eq(condition: "'news' in topics || 'owners' in topics")
  end

  it "targets a single topic directly" do
    expect(described_class.target_for_topics(%w[ all ])).to eq(topic: "all")
  end
end
