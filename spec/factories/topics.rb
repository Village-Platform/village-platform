FactoryBot.define do
  factory :topic do
    sequence(:key) { |n| "topic_#{n}" }
    sequence(:name) { |n| "موضوع #{n}" }
    public { false }

    trait(:listed) { public { true } }
  end
end
