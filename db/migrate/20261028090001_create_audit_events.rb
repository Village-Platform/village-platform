class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :actor, foreign_key: { to_table: :users }, index: false
      t.string :action, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :subject_label
      t.jsonb :changeset, null: false, default: {}
      t.string :source, null: false
      t.string :ip
      t.string :request_id
      t.datetime :created_at, null: false
    end

    add_index :audit_events, %i[subject_type subject_id created_at]
    add_index :audit_events, %i[actor_id created_at]
    add_index :audit_events, :created_at
    add_index :audit_events, :action
  end
end
