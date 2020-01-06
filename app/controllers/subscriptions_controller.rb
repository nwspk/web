class SubscriptionsController < ApplicationController
  layout 'subpage'
  before_filter :authenticate_user!
  before_action :set_subscription
  before_filter :require_selected_plan!

  def checkout
    @plan = @subscription.plan
    redirect_to dashboard_path if @plan.nil?
  end

  def edit
  end

  def update
    new_plan_id = params[:subscription][:plan_id] if params[:subscription]

    if @subscription.plan_id != new_plan_id && Plan.exists?(new_plan_id.to_i)
      service = ChangePlanService.new
      service.call(@subscription, new_plan_id)

      redirect_to dashboard_path, notice: "Successfully changed subscription plan to #{@subscription.plan.name}"
    else
      redirect_to edit_subscription_path, alert: 'No change was made since the same plan was selected'
    end
  end

  def destroy
    service = TerminateSubscriptionService.new
    service.call(@subscription)

    redirect_to dashboard_path, notice: 'Your subscription has been successfully terminated'
  end

  def process_card
    token = params[:stripeToken]

    if @subscription.customer_id.blank?
      customer = Stripe::Customer.create(
        source: token,
        email: current_user.email,
        description: current_user.name,
        account_balance: 0
      )

      #subscription = customer.subscriptions.create(plan: @subscription.plan.stripe_id)
      subscription = customer.subscriptions.create(plan: @subscription.plan.stripe_id, tax_percent: 20)

      @subscription.customer_id     = customer.id
      @subscription.subscription_id = subscription.id
      @subscription.active_until    = subscription.current_period_end
      @subscription.save!

      AdminMailer.new_subscriber_email(current_user).deliver_later

      redirect_to dashboard_path, notice: 'Congratulations!'
    else
      service = ChangeCardService.new
      service.call(@subscription.customer_id, token)

      redirect_to dashboard_path, notice: 'Credit card successfully changed!'
    end
  rescue Stripe::CardError => e
    render action: 'checkout', alert: e
  end

  private

  def set_subscription
    @subscription = current_user.subscription
  end

  def require_selected_plan!
    redirect_to(dashboard_path, alert: 'You do not have selected a plan to check out with') if @subscription.nil?
  end
end
