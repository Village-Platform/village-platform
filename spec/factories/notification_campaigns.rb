FactoryBot.define do
  factory :notification_campaign do
    title { "عرض جديد" }
    body { "تفاصيل العرض" }
    screen { "none" }
    scheduled_at { Time.current }
    topics { [ association(:topic, :listed) ] }
  end
end
