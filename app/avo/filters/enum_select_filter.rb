# Base select filter for an Active Record enum column. Subclasses set enum_model / enum_attribute.
class Avo::Filters::EnumSelectFilter < Avo::Filters::SelectFilter
  class_attribute :enum_model
  class_attribute :enum_attribute

  def apply(_request, query, value)
    return query if value.blank? || !enum_values.key?(value)

    query.where(enum_attribute => value)
  end

  def options
    enum_values.keys.index_with do |key|
      I18n.t("enums.#{enum_model.model_name.i18n_key}.#{enum_attribute}.#{key}", default: key.humanize)
    end
  end

  private

  def enum_values
    enum_model.public_send(enum_attribute.to_s.pluralize)
  end
end
