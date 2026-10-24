FactoryBot.define do
  factory :subscription do
    user
    subscription_plan
    payment_method { :instapay }
    sequence(:transaction_reference) { |n| "TX#{n.to_s.rjust(8, '0')}" }

    trait :current do
      status { :active }
      starts_at { 1.day.ago }
      ends_at { 29.days.from_now }
    end

    trait :expired do
      status { :active }
      starts_at { 40.days.ago }
      ends_at { 10.days.ago }
    end
  end
end
