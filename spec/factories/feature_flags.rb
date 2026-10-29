FactoryBot.define do
  factory :feature_flag do
    sequence(:key) { |n| "feature_#{n}" }
    enabled { false }
  end
end
