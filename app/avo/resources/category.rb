class Avo::Resources::Category < Avo::BaseResource
  self.title = :name
  self.translation_key = "avo.resource_translations.category"
  self.default_sort_column = :position
  self.default_sort_direction = :asc

  def fields
    field :id, as: :id
    field :name, as: :text, name: "اسم القسم", required: true
    field :description, as: :textarea, name: "الوصف"
    field :icon, as: :text, name: "الأيقونة"
    field :position, as: :number, name: "الترتيب"
    field :active, as: :boolean, name: "مفعّل"
    field :firms, as: :has_many, name: "المنشآت"
  end
end
