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
      position: plan.position,
      active: plan.active
    }
  end
end
