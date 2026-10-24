class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :phone, null: false
      t.string :email
      t.string :password_digest, null: false
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    add_index :users, :phone, unique: true
    add_index :users, :email, unique: true, where: "email IS NOT NULL"
    add_index :users, :role
  end
end
