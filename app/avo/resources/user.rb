class Avo::Resources::User < Avo::BaseResource
  self.title = :name
  self.translation_key = "avo.resource_translations.user"
  self.search = {
    query: -> {
      term = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
      query.where("users.name ILIKE :t OR users.phone ILIKE :t OR users.email ILIKE :t", t: term)
    }
  }

  def fields
    field :id, as: :id
    field :name, as: :text, name: "الاسم", required: true
    field :phone, as: :text, name: "رقم الهاتف", required: true
    field :email, as: :text, name: "البريد الإلكتروني"
    field :role, as: :select, name: "الصلاحية", enum: ::User.roles,
                 display_value: false, hide_on: [ :index, :show ]
    field :role, as: :badge, name: "الصلاحية",
                 options: { success: "super_admin", warning: "firm_admin", neutral: "user" }
    # Leave empty when editing to keep the current password.
    field :password, as: :password, name: "كلمة المرور", only_on: :forms
    field :created_at, as: :date_time, name: "تاريخ التسجيل", only_on: [ :index, :show ]

    field :firms, as: :has_many, name: "المنشآت"
    field :subscriptions, as: :has_many, name: "الاشتراكات"
  end

  def filters
    filter Avo::Filters::UserRole
  end
end
