class SubscriptionsController < ApplicationController
  before_filter :authenticate_user!
  before_action :set_subscription

  def checkout
  end

  def edit
  end

  def update
    new_plan_id = params[:subscription][:plan_id] if params[:subscription]

    if @subscription.plan_id != new_plan_id
      @subscription.update!(plan_id: new_plan_id)

      customer = Stripe::Customer.retrieve(@subscription.customer_id)

      if @subscription.subscription_id.blank?
        subscription = customer.subscriptions.create(plan: @subscription.plan.stripe_id)
        @subscription.update!(subscription_id: subscription.id, active_until: subscription.current_period_end)
      else
        subscription = customer.subscriptions.retrieve(@subscription.subscription_id)
        subscription.plan = @subscription.plan.stripe_id
        subscription.save
      end

      redirect_to dashboard_path, notice: "Successfully changed subscription plan to #{@subscription.plan.name}" and return
    end

    redirect_to edit_subscription_path, alert: 'No change was made since the same plan was selected'
  end

  def destroy
    unless @subscription.subscription_id.blank?
      customer = Stripe::Customer.retrieve(@subscription.customer_id)
      customer.subscriptions.retrieve(@subscription.subscription_id).delete

      @subscription.update(subscription_id: '', plan_id: nil, active_until: nil)
    end

    redirect_to dashboard_path, notice: 'Your subscription has been successfully terminated'
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
    @subscription.active_until    = subscription.current_period_end
    @subscription.save!

    # Setup fee
    Stripe::InvoiceItem.create(
      customer: customer.id,
      amount: 10000,
      currency: 'gbp',
      description: 'One-time setup fee'
    )

    redirect_to dashboard_path, notice: 'Congratulations!'
  rescue Stripe::CardError => e
    render action: 'checkout', alert: e
  end

  private

  def set_subscription
    @subscription = current_user.subscription
  end
end
