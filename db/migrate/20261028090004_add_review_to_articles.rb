# Subscribers can now write articles, so they go through review. Existing rows were written by
# super admins and are trusted: the default (approved) keeps every one of them public.
class AddReviewToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :review_state, :integer, null: false, default: 0
    add_column :articles, :rejection_reason, :string, limit: 300
    add_reference :articles, :firm, foreign_key: true
    add_reference :articles, :reviewed_by, foreign_key: { to_table: :users }, index: false
    add_column :articles, :reviewed_at, :datetime
    add_index :articles, :review_state, where: "review_state = 1", name: "index_articles_pending_review"
  end
end
