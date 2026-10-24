class Avo::Filters::SubscriptionStatus < Avo::Filters::EnumSelectFilter
  self.name = "الحالة"
  self.enum_model = ::Subscription
  self.enum_attribute = :status
end
