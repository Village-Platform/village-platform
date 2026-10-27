# Upload pipeline shared by every attachment: MediaProfile defines the target, Media::Validate
# and Media::Optimize enforce it, Media::Ingest ties them together for a controller.
module Media
  DATABASE_SERVICE = "ActiveStorage::Service::DatabaseService".freeze

  # Video must not land in PostgreSQL: it would fill the database disk and every backup.
  def self.service_name_for(profile)
    name = profile.object_storage ? MediaProfile.object_storage_service : nil
    name ||= ActiveStorage::Blob.service.name
    raise InvalidFile.new("media_storage_unavailable") if profile.object_storage && database_service?(name)

    name
  end

  def self.database_service?(name)
    ActiveStorage::Blob.services.fetch(name.to_sym).class.name == DATABASE_SERVICE
  end
end
