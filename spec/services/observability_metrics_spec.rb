require "rails_helper"

RSpec.describe Observability::Metrics do
  it "is a no-op until installed" do
    expect { described_class.increment(:api_errors, code: "not_found", status: 404) }.not_to raise_error
  end

  it "rejects attributes a metric does not declare, so ids never become labels" do
    expect { described_class.increment(:api_errors, code: "not_found", user_id: 1) }
      .to raise_error(ArgumentError, /user_id/)
  end

  it "rejects unknown metrics" do
    expect { described_class.increment(:typo) }.to raise_error(ArgumentError, /typo/)
  end

  it "drops undeclared attributes in production instead of failing the request", :metrics do
    allow(Rails.env).to receive(:production?).and_return(true)

    described_class.increment(:api_errors, code: "not_found", status: 404, user_id: 1)

    expect(metric_points("aghour.api.errors").map(&:attributes)).to eq([ { "code" => "not_found", "status" => 404 } ])
  end

  it "starts closed-set counters at zero, so the first increase() is visible", :metrics do
    expect(metric_points("aghour.reminders.runs").map(&:attributes))
      .to contain_exactly({ "result" => "success" }, { "result" => "failure" })
    expect(metric_value("aghour.reminders.runs")).to eq(0)
  end

  it "uses the declared histogram buckets", :metrics do
    described_class.record(:subscription_review_wait, 90, outcome: "approved")

    point = metric_points("aghour.subscription.review.wait").sole
    expect(point.explicit_bounds.first).to eq(5.minutes.to_i)
  end
end
