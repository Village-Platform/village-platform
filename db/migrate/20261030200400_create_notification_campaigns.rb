# An admin message sent to one or more topics, now or later; also created on article publish.
class CreateNotificationCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_campaigns do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.string :screen, null: false, default: "none"
      t.bigint :target_id
      t.integer :status, null: false, default: 0
      t.datetime :scheduled_at, null: false
      t.datetime :sent_at
      t.integer :recipients_count
      t.string :fcm_message_name
      t.text :last_error
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :article, foreign_key: true, index: { unique: true, where: "article_id IS NOT NULL" }
      t.timestamps
    end
    add_index :notification_campaigns, %i[ status scheduled_at ]

    create_table :campaign_topics do |t|
      t.references :notification_campaign, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :topic, null: false, foreign_key: true
      t.timestamps
    end
    add_index :campaign_topics, %i[ notification_campaign_id topic_id ], unique: true

    add_reference :notifications, :campaign, foreign_key: { to_table: :notification_campaigns }
  end
end
