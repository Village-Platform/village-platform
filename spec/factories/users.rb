FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:phone) { |n| format("010%08d", n) }
    password { "password123" }
    role { :user }

    trait(:firm_admin)  { role { :firm_admin } }
    trait(:super_admin) { role { :super_admin } }
  end
end
