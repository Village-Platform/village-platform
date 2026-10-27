class CreateStaffPermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_permissions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :permission, null: false
      t.references :granted_by, foreign_key: { to_table: :users }, index: false
      t.datetime :created_at, null: false
    end

    add_index :staff_permissions, %i[user_id permission], unique: true
  end
end
