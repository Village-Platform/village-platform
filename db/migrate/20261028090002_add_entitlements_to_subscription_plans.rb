# Each limit gets a default that keeps today's behaviour, so existing plans need no backfill.
class AddEntitlementsToSubscriptionPlans < ActiveRecord::Migration[8.1]
  LIMITS = {
    max_images_per_firm: 5,
    max_videos_per_firm: 0,
    max_video_seconds: 60,
    max_articles_per_month: 0
  }.freeze

  def change
    LIMITS.each do |column, default|
      add_column :subscription_plans, column, :integer, null: false, default: default
      add_check_constraint :subscription_plans, "#{column} >= 0", name: "subscription_plans_#{column}_non_negative"
    end

    add_column :subscription_plans, :priority, :integer, null: false, default: 0
    add_check_constraint :subscription_plans, "priority BETWEEN 0 AND 100", name: "subscription_plans_priority_range"
  end
end
