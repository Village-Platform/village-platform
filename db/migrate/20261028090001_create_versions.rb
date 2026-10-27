# PaperTrail's versions table (jsonb object and object_changes), plus metadata columns filled
# from PaperTrail.request.controller_info and has_paper_trail meta:
#   operation  — the business action ("firm.suspend"); nil for a plain save
#   item_label — what the record was called, kept after it is deleted
#   source     — admin / api / cron, or system for seeds, consoles and jobs
class CreateVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :versions do |t|
      t.string :whodunnit
      t.datetime :created_at, null: false
      t.bigint :item_id, null: false
      t.string :item_type, null: false
      t.string :event, null: false
      t.jsonb :object
      t.jsonb :object_changes
      t.string :operation
      t.string :item_label
      t.string :source, null: false, default: "system"
      t.string :ip
      t.string :request_id
    end

    add_index :versions, %i[item_type item_id created_at]
    add_index :versions, %i[whodunnit created_at]
    add_index :versions, :created_at
  end
end
