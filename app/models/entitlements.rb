# What a user may do, read from the plan of their current subscription.
# A nil limit means unlimited (super admins); no subscription means every limit is zero.
#
#   user.entitlements.within?(:max_firms, user.firms.count)
Entitlements = Data.define(:max_firms, :max_images_per_firm, :max_videos_per_firm, :max_video_seconds,
                           :max_articles_per_month, :priority) do
  def self.for(user)
    return unlimited if user&.super_admin?

    plan = user&.current_subscription&.subscription_plan
    plan ? from_plan(plan) : none
  end

  def self.from_plan(plan)
    new(**members.index_with { |limit| plan.public_send(limit) })
  end

  def self.unlimited
    new(**members.index_with { nil }.merge(priority: 0))
  end

  def self.none
    new(**members.index_with { 0 })
  end

  def within?(limit, used)
    value = public_send(limit)
    value.nil? || used < value
  end
end
