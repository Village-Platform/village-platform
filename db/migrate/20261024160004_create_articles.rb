class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body, null: false
      t.integer :kind, null: false, default: 0
      t.datetime :published_at

      t.timestamps
    end

    add_index :articles, :published_at
    add_index :articles, %i[kind published_at]
  end
end
