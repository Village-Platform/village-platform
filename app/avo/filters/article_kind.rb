class Avo::Filters::ArticleKind < Avo::Filters::EnumSelectFilter
  self.name = "النوع"
  self.enum_model = ::Article
  self.enum_attribute = :kind
end
