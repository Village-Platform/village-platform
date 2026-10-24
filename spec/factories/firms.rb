FactoryBot.define do
  factory :firm do
    category
    association :owner, factory: %i[user firm_admin]
    sequence(:name) { |n| "Firm #{n}" }
    phone { "01012345678" }
    status { :active }

    trait(:pending) { status { :pending } }
  end
end
