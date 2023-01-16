class ChangePlanService
  def call(subscription_record, new_plan_id)
    subscription_record.update!(plan_id: new_plan_id)

    return if subscription_record.customer_id.blank?

    if subscription_record.subscription_id.blank?
      create_new_subscription(subscription_record)
    else
      begin
        subscription = Stripe::Subscription.retrieve(subscription_record.subscription_id)
      rescue Stripe::InvalidRequestError
        subscription = nil
      end

      if subscription.nil?
        create_new_subscription(subscription_record)
      else
        change_plan_on_existing_subscription(subscription, subscription_record)
      end
    end
  end

  private

  def create_new_subscription(subscription_record)
    subscription = Stripe::Subscription.create(plan: subscription_record.plan.stripe_id)
    subscription_record.update!(subscription_id: subscription.id, active_until: arbitrary_future_date)
  end

  def change_plan_on_existing_subscription(subscription, subscription_record)
    subscription.plan = subscription_record.plan.stripe_id
    subscription.save
  end

  def arbitrary_future_date
    30.days.from_now
  end
end
