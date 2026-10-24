class Avo::Filters::SubscriptionPaymentMethod < Avo::Filters::EnumSelectFilter
  self.name = "طريقة الدفع"
  self.enum_model = ::Subscription
  self.enum_attribute = :payment_method
end
