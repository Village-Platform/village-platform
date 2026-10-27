class FirmSerializer
  # Expects :category (and its icon attachment) to be preloaded on collections.
  def self.render(firm)
    {
      id: firm.id,
      name: firm.name,
      description: firm.description,
      phone: firm.phone,
      whatsapp: firm.whatsapp,
      address: firm.address,
      latitude: firm.latitude&.to_f,
      longitude: firm.longitude&.to_f,
      working_hours: firm.working_hours,
      status: firm.status,
      owner_id: firm.owner_id,
      category: { id: firm.category.id, name: firm.category.name, icon: firm.category.icon, icon_url: firm.category.icon_url },
      created_at: firm.created_at
    }
  end
end
