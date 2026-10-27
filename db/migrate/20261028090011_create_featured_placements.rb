class CreateFeaturedPlacements < ActiveRecord::Migration[8.1]
  def change
    create_table :featured_placements do |t|
      t.references :firm, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :position, null: false, default: 0
      t.string :note, limit: 200
      t.references :created_by, foreign_key: { to_table: :users }, index: false
      t.timestamps
    end

    add_index :featured_placements, %i[starts_at ends_at]
    add_check_constraint :featured_placements, "ends_at > starts_at", name: "featured_placements_period_valid"
  end
end
