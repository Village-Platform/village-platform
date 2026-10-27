class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }, index: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.integer :reason, null: false
      t.string :note, limit: 500
      t.integer :status, null: false, default: 0
      t.references :resolved_by, foreign_key: { to_table: :users }, index: false
      t.string :resolution_note, limit: 300
      t.datetime :resolved_at
      t.timestamps
    end

    # One open report per user per subject; a resolved one can be reported again.
    add_index :reports, %i[reporter_id subject_type subject_id], unique: true, where: "status = 0",
              name: "index_reports_one_open_per_reporter"
    add_index :reports, %i[subject_type subject_id status]
    add_index :reports, :status, where: "status = 0", name: "index_reports_open"
  end
end
