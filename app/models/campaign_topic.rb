class CampaignTopic < ApplicationRecord
  belongs_to :notification_campaign
  belongs_to :topic
end
