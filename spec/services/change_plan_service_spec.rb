require 'rails_helper'

RSpec.describe ChangePlanService, type: :model do
  before :all do
    StripeMock.start
  end

  after :all do
    StripeMock.stop
  end

  let(:stripe_helper) { StripeMock.create_test_helper }
  let(:user) { Fabricate(:user) }
  let(:subscription) { user.build_subscription }
  let(:plan1) { Fabricate(:plan) }
  let(:plan2) { Fabricate(:plan) }

  before do
    customer = Stripe::Customer.create({
      email: user.email,
      source: stripe_helper.generate_card_token
    })

    subscription.customer_id = customer.id
  end

  describe 'creates a new Stripe subscription if none is on record' do
    before do
      service = ChangePlanService.new
      service.(subscription, plan1.id)
    end

    it 'sets the plan' do
      expect(subscription.plan_id).to eq plan1.id
    end

    it 'saves the new Stripe subscription ID' do
      expect(subscription.subscription_id).to_not be_empty
    end

    it 'sets an active_until date in the future' do
      expect(subscription.active_until).to_not be_nil
    end
  end

  describe 'changes an existing Stripe subscription' do
    before do
      stripe_subscription = Stripe::Customer.retrieve(subscription.customer_id).subscriptions.create(plan: plan1.stripe_id)
      subscription.update!(subscription_id: stripe_subscription.id, plan_id: plan1.id, active_until: 30.days.from_now)

      service = ChangePlanService.new
      service.(subscription, plan2.id)
    end

    it 'sets the plan' do
      expect(subscription.plan_id).to eq plan2.id
    end

    it 'sets the remote plan' do
      stripe_subscription = Stripe::Customer.retrieve(subscription.customer_id).subscriptions.retrieve(subscription.subscription_id)
      expect(stripe_subscription.plan.id).to eql plan2.stripe_id
    end
  end
end
