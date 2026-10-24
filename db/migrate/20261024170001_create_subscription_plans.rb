class CreateSubscriptionPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_plans do |t|
      t.string :name, null: false
      t.text :description
      t.integer :price_cents, null: false # EGP piasters (100 = 1 EGP)
      t.integer :duration_days, null: false
      t.integer :max_firms, null: false, default: 1
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :subscription_plans, :name, unique: true
    add_check_constraint :subscription_plans, "price_cents >= 0", name: "subscription_plans_price_non_negative"
    add_check_constraint :subscription_plans, "duration_days > 0", name: "subscription_plans_duration_positive"
    add_check_constraint :subscription_plans, "max_firms > 0", name: "subscription_plans_max_firms_positive"
  end
end
