require "rails_helper"

RSpec.describe Fcm::Message do
  it "builds a payload without a target and stringifies data values" do
    payload = described_class.payload(title: "T", body: "B", data: { id: 42, screen: :article })
    expect(payload[:data]).to eq("id" => "42", "screen" => "article")
    expect(payload[:notification]).to eq(title: "T", body: "B")
    expect(payload.dig(:android, :priority)).to eq("high")
    expect(payload.keys).not_to include(:token, :topic, :condition)
  end

  it "builds an any-of condition by default" do
    expect(described_class.condition_for(%w[ news owners ])).to eq("'news' in topics || 'owners' in topics")
  end

  it "builds an all-of condition" do
    expect(described_class.condition_for(%w[ news owners ], operator: :and)).to eq("'news' in topics && 'owners' in topics")
  end

  it "rejects an unknown operator" do
    expect { described_class.condition_for(%w[ a b ], operator: :xor) }.to raise_error(KeyError)
  end
end
