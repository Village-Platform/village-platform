FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    sequence(:position) { |n| n }
    active { true }
  end
end
