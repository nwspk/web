class TerminateSubscriptionService
  def call(subscription)
    return if subscription.subscription_id.blank?

    Stripe::Subscription.cancel(subscription.subscription_id)

    return if subscription.destroyed?

    subscription.update(subscription_id: '', plan_id: nil, active_until: nil)
  end
end
