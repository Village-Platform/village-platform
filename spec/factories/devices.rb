FactoryBot.define do
  factory :device do
    sequence(:installation_id) { |n| "install-#{n}" }
    sequence(:token) { |n| "fcm-token-#{n}" }
    platform { "android" }
  end
end
