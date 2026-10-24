FactoryBot.define do
  factory :article do
    association :author, factory: %i[user super_admin]
    sequence(:title) { |n| "Article #{n}" }
    body { "Body" }
    kind { :news }
    published_at { 1.hour.ago }

    trait(:draft) { published_at { nil } }
  end
end
