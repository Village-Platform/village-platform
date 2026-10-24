class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.integer :kind, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :read_at
      # Prevents sending the same reminder twice (e.g. "subscription:5:expiring:7").
      t.string :dedupe_key

      t.timestamps
    end

    add_index :notifications, %i[user_id created_at]
    add_index :notifications, :user_id, where: "read_at IS NULL", name: "index_notifications_unread_by_user"
    add_index :notifications, :dedupe_key, unique: true, where: "dedupe_key IS NOT NULL"
  end
end
