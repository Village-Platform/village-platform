class Avo::Resources::Firm < Avo::BaseResource
  self.title = :name
  self.translation_key = "avo.resource_translations.firm"
  self.includes = [ :category, :owner ]
  self.search = {
    query: -> { query.where("firms.name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(q)}%") }
  }

  def fields
    field :id, as: :id
    field :name, as: :text, name: "اسم المنشأة", required: true
    field :status, as: :badge, name: "الحالة",
                   options: { success: "active", warning: "pending", danger: "suspended" }
    field :status, as: :select, name: "الحالة", enum: ::Firm.statuses,
                   display_value: false, hide_on: [ :index, :show ]
    field :category, as: :belongs_to, name: "القسم"
    field :owner, as: :belongs_to, name: "المالك"
    field :phone, as: :text, name: "الهاتف"
    field :whatsapp, as: :text, name: "واتساب", hide_on: :index
    field :address, as: :text, name: "العنوان", hide_on: :index
    field :working_hours, as: :text, name: "مواعيد العمل", hide_on: :index
    field :latitude, as: :number, name: "خط العرض", step: 0.000001, hide_on: :index
    field :longitude, as: :number, name: "خط الطول", step: 0.000001, hide_on: :index
    field :description, as: :textarea, name: "الوصف"
    field :created_at, as: :date_time, name: "تاريخ الإضافة", only_on: [ :index, :show ]
  end

  def filters
    filter Avo::Filters::FirmStatus
  end

  def actions
    action Avo::Actions::ApproveFirm, icon: "heroicons/outline/check-circle"
    action Avo::Actions::SuspendFirm, icon: "heroicons/outline/no-symbol"
  end
end
