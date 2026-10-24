class CategorySerializer
  def self.render(category)
    {
      id: category.id,
      name: category.name,
      description: category.description,
      icon: category.icon,
      position: category.position,
      active: category.active
    }
  end
end
