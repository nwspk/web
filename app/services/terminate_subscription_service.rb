class TerminateSubscriptionService
  def call(subscription)
    return if subscription.subscription_id.blank?

    customer = Stripe::Customer.retrieve(subscription.customer_id)
    customer.subscriptions.retrieve(subscription.subscription_id).delete
    subscription.update(subscription_id: '', plan_id: nil, active_until: nil)
  end
end
