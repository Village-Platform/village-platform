FactoryBot.define do
  factory :subscription_plan do
    sequence(:name) { |n| "Plan #{n}" }
    price_cents { 10_000 }
    duration_days { 30 }
    max_firms { 1 }
    active { true }
  end
end
