class AddReconciliationNoteToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :reconciliation_note, :string, limit: 300
  end
end
