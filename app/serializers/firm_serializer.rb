class FirmSerializer
  # Expects :category (and its icon attachment) and media (with file blobs) to be preloaded on
  # collections. cover_image_url and media_count are additive; the gallery has its own endpoint.
  def self.render(firm)
    images = firm.media.select(&:image?)
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
      cover_image_url: (FirmMediumSerializer.render(images.first)[:thumbnail_url] if images.any?),
      media_count: { images: images.size, videos: firm.media.count(&:video?) },
      created_at: firm.created_at
    }
  end
end
