class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :key, null: false
      t.jsonb :value
      t.references :updated_by, foreign_key: { to_table: :users }, index: false
      t.datetime :updated_at, null: false
    end

    add_index :settings, :key, unique: true
  end
end
