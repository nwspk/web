class SubscriptionsController < ApplicationController
  before_filter :authenticate_user!
  before_action :set_subscription

  def checkout
  end

  def process_card
    token = params[:stripeToken]

    customer = Stripe::Customer.create(
      source: token,
      email: current_user.email,
      description: current_user.name
    )

    subscription = customer.subscriptions.create(plan: @subscription.plan.stripe_id)

    @subscription.customer_id     = customer.id
    @subscription.subscription_id = subscription.id
    @subscription.save

    redirect_to dashboard_path, notice: 'Congratulations!'
  rescue Stripe::CardError => e
    render action: 'checkout', alert: e
  end

  private

  def set_subscription
    @subscription = current_user.subscription
  end
end
