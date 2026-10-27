class CreateFirmMedia < ActiveRecord::Migration[8.1]
  def change
    create_table :firm_media do |t|
      t.references :firm, null: false, foreign_key: true, index: false
      t.integer :kind, null: false
      t.integer :position, null: false, default: 0
      t.string :caption, limit: 200
      t.integer :duration_s
      t.timestamps
    end

    add_index :firm_media, %i[firm_id kind position]
    add_check_constraint :firm_media, "position >= 0", name: "firm_media_position_non_negative"
    add_check_constraint :firm_media, "kind IN (0, 1)", name: "firm_media_kind_known"
  end
end
