class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :subscription_plan, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }

      t.integer :status, null: false, default: 0
      t.integer :payment_method, null: false
      t.integer :amount_cents, null: false # snapshot of the plan price at request time
      t.string :transaction_reference, null: false
      t.string :payer_phone
      t.text :notes

      t.datetime :starts_at
      t.datetime :ends_at
      t.datetime :reviewed_at
      t.text :rejection_reason

      t.timestamps
    end

    # The same InstaPay / Vodafone Cash transfer can't be used twice.
    add_index :subscriptions, %i[payment_method transaction_reference], unique: true,
              name: "index_subscriptions_on_payment_reference"
    # Only one pending request per user at a time.
    add_index :subscriptions, :user_id, unique: true, where: "status = 0",
              name: "index_subscriptions_one_pending_per_user"
    add_index :subscriptions, %i[status ends_at]
    add_index :subscriptions, %i[user_id status ends_at]
  end
end
