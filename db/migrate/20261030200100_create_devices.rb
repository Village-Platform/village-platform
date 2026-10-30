# One row per app install. installation_id is the natural key (stable per install); the FCM token
# rotates and is updated in place. user_id is null for a guest.
class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.string :installation_id, null: false, index: { unique: true }
      t.string :token, null: false, index: { unique: true }
      t.references :user, foreign_key: true
      t.string :platform, null: false, default: "android"
      t.string :locale
      t.string :app_version
      t.datetime :last_seen_at
      t.timestamps
    end
  end
end
