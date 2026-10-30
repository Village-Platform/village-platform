# Exactly one of user / device (database check constraint).
class TopicSubscription < ApplicationRecord
  belongs_to :topic
  belongs_to :user, optional: true
  belongs_to :device, optional: true
end
