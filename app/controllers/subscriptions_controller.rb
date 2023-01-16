class SubscriptionsController < ApplicationController
  layout 'subpage'
  before_action :authenticate_user!
  before_action :set_subscription
  before_action :require_selected_plan!

  def create_checkout_session
    begin
      session = Stripe::Checkout::Session.create(
        {
          mode: 'subscription',
          line_items: [
            {
              quantity: 1,
              price: @subscription.plan.stripe_id,
              tax_rates: [STRIPE_TAX_RATE_ID]
            }
          ],
          success_url: "#{CANONICAL_URL}#{process_card_subscription_path}?session_id={CHECKOUT_SESSION_ID}",
          cancel_url: "#{CANONICAL_URL}#{process_card_subscription_path}"
        }
      )
    rescue StandardError => e
      response = { error: { message: e.error.message } }.to_json
      render json: response, status: :bad_request
    end

    redirect_to session.url, status: :see_other
  end

  def checkout
    @plan = @subscription.plan
    redirect_to dashboard_path if @plan.nil?
  end

  def edit; end

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
    stripe_session_id = params[:session_id]

    return if stripe_session_id.blank?

    checkout = Stripe::Checkout::Session.retrieve(stripe_session_id)
    @subscription.customer_id = checkout.customer
    @subscription.subscription_id = checkout.subscription

    stripe_subscription = Stripe::Subscription.retrieve(@subscription.subscription_id)
    @subscription.active_until = Time.zone.at(stripe_subscription.current_period_end).to_fs(:db)
    @subscription.save!

    AdminMailer.new_subscriber_email(current_user).deliver_later

    redirect_to dashboard_path, notice: 'Congratulations!'
  end

  private

  def set_subscription
    @subscription = current_user.subscription
  end

  def require_selected_plan!
    redirect_to(dashboard_path, alert: 'You do not have selected a plan to check out with') if @subscription.nil?
  end
end
