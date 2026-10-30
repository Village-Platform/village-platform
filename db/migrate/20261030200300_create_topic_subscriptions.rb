# A user (admin assignment or signed-in opt-in) or a guest device belongs to a topic. Exactly one of
# the two, enforced by the database.
class CreateTopicSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :topic_subscriptions do |t|
      t.references :topic, null: false, foreign_key: true, index: false
      t.references :user, foreign_key: true
      t.references :device, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_check_constraint :topic_subscriptions, "num_nonnulls(user_id, device_id) = 1", name: "topic_subscriptions_one_subscriber"
    add_index :topic_subscriptions, %i[ topic_id user_id ], unique: true, where: "user_id IS NOT NULL"
    add_index :topic_subscriptions, %i[ topic_id device_id ], unique: true, where: "device_id IS NOT NULL"
  end
end
