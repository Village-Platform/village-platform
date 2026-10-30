class AddDeletedAtToFirms < ActiveRecord::Migration[8.1]
  def change
    add_column :firms, :deleted_at, :datetime
  end
end
