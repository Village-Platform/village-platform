# Account deletion keeps the user row as an anonymised tombstone (subscriptions are payment
# records with a NOT NULL user_id), so "deleted" is a timestamp rather than a missing row.
class AddDeletedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :deleted_at, :datetime
  end
end
