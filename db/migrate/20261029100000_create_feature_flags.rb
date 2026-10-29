# On/off switches the apps read from GET /api/v1/app_config, managed from the dashboard.
# `key` is a contract with the Android client, so it is constrained here and read-only in the model.
class CreateFeatureFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_flags do |t|
      t.string :key, null: false
      t.boolean :enabled, null: false, default: false
      t.text :description
      t.timestamps
    end
    add_index :feature_flags, :key, unique: true
    add_check_constraint :feature_flags, "key ~ '^[a-z][a-z0-9_]*$'", name: "feature_flags_key_format"
  end
end
