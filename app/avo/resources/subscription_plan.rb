class Avo::Resources::SubscriptionPlan < Avo::BaseResource
  self.title = :name
  self.translation_key = "avo.resource_translations.subscription_plan"
  self.default_sort_column = :position
  self.default_sort_direction = :asc

  def fields
    field :id, as: :id
    field :name, as: :text, name: "اسم الباقة", required: true
    field :price_cents, as: :number, name: "السعر (قرش)", help: "100 قرش = 1 جنيه", required: true
    field :price, as: :text, name: "السعر", only_on: [ :index, :show ] do
      "#{(record.price_cents / 100.0).round(2)} ج.م"
    end
    field :duration_days, as: :number, name: "المدة (يوم)", required: true
    field :max_firms, as: :number, name: "أقصى عدد منشآت", required: true
    field :position, as: :number, name: "الترتيب"
    field :active, as: :boolean, name: "مفعّلة"
    field :description, as: :textarea, name: "الوصف", hide_on: :index
  end
end
