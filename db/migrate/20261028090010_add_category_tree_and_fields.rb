class AddCategoryTreeAndFields < ActiveRecord::Migration[8.1]
  def change
    add_reference :categories, :parent, foreign_key: { to_table: :categories }
    add_column :categories, :children_count, :integer, null: false, default: 0

    create_table :category_fields do |t|
      t.references :category, null: false, foreign_key: true, index: false
      t.string :key, null: false, limit: 40
      t.string :label, null: false, limit: 80
      t.integer :kind, null: false, default: 0
      t.jsonb :options, null: false, default: []
      t.integer :position, null: false, default: 0
      t.boolean :required, null: false, default: false
      t.timestamps
    end
    add_index :category_fields, %i[category_id key], unique: true
    add_index :category_fields, %i[category_id position]

    add_column :firms, :custom_fields, :jsonb, null: false, default: {}
  end
end
