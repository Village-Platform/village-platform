# Body of an Active Storage file kept in PostgreSQL (see ActiveStorage::Service::DatabaseService).
class StoredFile < ApplicationRecord
  validates :key, presence: true, uniqueness: true
end
