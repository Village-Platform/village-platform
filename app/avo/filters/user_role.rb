class Avo::Filters::UserRole < Avo::Filters::EnumSelectFilter
  self.name = "الصلاحية"
  self.enum_model = ::User
  self.enum_attribute = :role
end
