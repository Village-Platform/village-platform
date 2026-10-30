# The topic an article is pushed to when it goes live (Articles::SyncPushCampaign).
class AddNotifyTopicIdToArticles < ActiveRecord::Migration[8.1]
  def change
    add_reference :articles, :notify_topic, foreign_key: { to_table: :topics, on_delete: :nullify }
  end
end
