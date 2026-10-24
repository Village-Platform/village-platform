class SubscriptionSerializer
  # Expects :subscription_plan, the screenshot attachment (and :user for admin lists)
  # to be preloaded on collections.
  def self.render(subscription, include_user: false)
    data = {
      id: subscription.id,
      status: subscription.status,
      state: subscription.state,
      plan: {
        id: subscription.subscription_plan.id,
        name: subscription.subscription_plan.name,
        duration_days: subscription.subscription_plan.duration_days,
        max_firms: subscription.subscription_plan.max_firms
      },
      payment_method: subscription.payment_method,
      amount_cents: subscription.amount_cents,
      currency: "EGP",
      transaction_reference: subscription.transaction_reference,
      payer_phone: subscription.payer_phone,
      notes: subscription.notes,
      has_payment_screenshot: subscription.payment_screenshot.attached?,
      days_left: subscription.days_left,
      starts_at: subscription.starts_at,
      ends_at: subscription.ends_at,
      reviewed_at: subscription.reviewed_at,
      rejection_reason: subscription.rejection_reason,
      created_at: subscription.created_at
    }
    if include_user
      data[:user] = { id: subscription.user.id, name: subscription.user.name, phone: subscription.user.phone }
    end
    data
  end
end
