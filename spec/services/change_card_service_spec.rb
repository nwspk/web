require 'rails_helper'

RSpec.describe ChangeCardService, type: :model do
  let(:stripe_helper) { StripeMock.create_test_helper }
  let(:user) { Fabricate(:user) }
  let(:subscription) { user.build_subscription }

  before do
    customer = Stripe::Customer.create({
      email: user.email,
      source: stripe_helper.generate_card_token
    })

    subscription.customer_id = customer.id
  end

  it 'changes the default card of the customer' do
    old_card_id = Stripe::Customer.retrieve(subscription.customer_id).default_source
    service = ChangeCardService.new
    service.call(subscription.customer_id, stripe_helper.generate_card_token)
    new_card_id = Stripe::Customer.retrieve(subscription.customer_id).default_source
    expect(new_card_id).to_not eql old_card_id
  end
end
