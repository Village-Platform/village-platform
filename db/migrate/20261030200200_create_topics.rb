class CreateTopics < ActiveRecord::Migration[8.1]
  def change
    create_table :topics do |t|
      t.string :key, null: false, index: { unique: true }
      t.string :name, null: false
      t.text :description
      t.boolean :public, null: false, default: false
      t.boolean :system, null: false, default: false
      t.timestamps
    end
  end
end
