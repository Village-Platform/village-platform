FactoryBot.define do
  factory :report do
    association :reporter, factory: :user
    association :subject, factory: :firm
    reason { :wrong_info }
  end
end
