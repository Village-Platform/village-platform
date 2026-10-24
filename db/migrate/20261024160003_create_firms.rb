class CreateFirms < ActiveRecord::Migration[8.1]
  def change
    create_table :firms do |t|
      t.references :category, null: false, foreign_key: true
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :description
      t.string :phone
      t.string :whatsapp
      t.string :address
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :working_hours
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :firms, %i[category_id status]
    add_index :firms, :status
  end
end
