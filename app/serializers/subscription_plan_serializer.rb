class SubscriptionPlanSerializer
  def self.render(plan)
    {
      id: plan.id,
      name: plan.name,
      description: plan.description,
      price_cents: plan.price_cents,
      currency: "EGP",
      duration_days: plan.duration_days,
      max_firms: plan.max_firms,
      max_images_per_firm: plan.max_images_per_firm,
      max_videos_per_firm: plan.max_videos_per_firm,
      max_video_seconds: plan.max_video_seconds,
      max_articles_per_month: plan.max_articles_per_month,
      priority: plan.priority,
      position: plan.position,
      active: plan.active
    }
  end
end
