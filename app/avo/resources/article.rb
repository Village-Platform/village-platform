class Avo::Resources::Article < Avo::BaseResource
  self.title = :title
  self.translation_key = "avo.resource_translations.article"
  self.includes = [ :author ]
  self.default_sort_column = :published_at

  def fields
    field :id, as: :id
    field :title, as: :text, name: "العنوان", required: true
    field :kind, as: :select, name: "النوع", enum: ::Article.kinds, display_value: false
    field :published_at, as: :date_time, name: "تاريخ النشر",
                         help: "اتركه فارغًا ليبقى مسودة. التاريخ المستقبلي = نشر مجدول."
    field :author, as: :belongs_to, name: "الكاتب"
    field :body, as: :textarea, name: "المحتوى", rows: 12, hide_on: :index, required: true
  end

  def filters
    filter Avo::Filters::ArticleKind
  end
end
