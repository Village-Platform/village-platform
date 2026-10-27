class CategorySerializer
  def self.render(category)
    {
      id: category.id,
      name: category.name,
      description: category.description,
      icon: category.icon,
      icon_url: category.icon_url,
      position: category.position,
      active: category.active,
      parent_id: category.parent_id,
      children_count: category.children_count,
      fields: category.fields.map(&:as_json)
    }
  end
end
