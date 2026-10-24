class Avo::Filters::FirmStatus < Avo::Filters::EnumSelectFilter
  self.name = "الحالة"
  self.enum_model = ::Firm
  self.enum_attribute = :status
end
