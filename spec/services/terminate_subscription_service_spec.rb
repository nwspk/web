require 'rails_helper'

RSpec.describe TerminateSubscriptionService, type: :model do
  let(:stripe_helper) { StripeMock.create_test_helper }
  let(:user) { Fabricate(:user) }
  let(:subscription) { user.build_subscription }
  let(:plan) { Fabricate(:plan, name: 'p') }

  before do
    Stripe::Plan.create(
      amount: plan.value.cents,
      name: plan.name,
      id: plan.stripe_id,
      interval: 'month',
      currency: plan.value.currency.iso_code
    )

    customer = Stripe::Customer.create({
      email: 'johnny@appleseed.com',
      source: stripe_helper.generate_card_token
    })

    stripe_subscription = customer.subscriptions.create(plan: plan.stripe_id)

    subscription.update(customer_id: customer.id, subscription_id: stripe_subscription.id, active_until: 30.days.from_now)
  end

  it 'removes subscription details from the database' do
    service = TerminateSubscriptionService.new
    service.(subscription)

    expect(subscription.active?).to be false
  end

  it 'terminates the subscription when a user is destroyed' do
    user.destroy
  end
end
