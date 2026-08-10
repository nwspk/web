require 'rails_helper'

RSpec.describe WebhooksController, type: :controller do
  before do
    Timecop.freeze(Time.local(2015, 4, 23, 0, 46, 0))
  end

  after do
    Timecop.return
  end

  let(:subscription) { Fabricate(:subscription, customer_id: "foo_000") }

  # The controller verifies webhook signatures (Stripe::Webhook.construct_event),
  # so requests must carry a valid Stripe-Signature header.
  def post_signed(payload)
    payload = payload.to_s unless payload.is_a?(String)
    timestamp = Time.now
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, STRIPE_WEBHOOK_SECRET)
    request.headers['Stripe-Signature'] = "t=#{timestamp.to_i},v1=#{signature}"
    post :index, body: payload
  end

  describe "POST #index" do
    it 'rejects an unsigned request' do
      post :index
      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects a request with an invalid signature' do
      request.headers['Stripe-Signature'] = 't=123,v1=bogus'
      post :index, body: { id: 'fake' }.to_json
      expect(response).to have_http_status(:bad_request)
    end

    it 'accepts a signed event of an unhandled type' do
      post_signed({ id: 'evt_1', type: 'customer.created', data: { object: { id: 'cus_1' } } }.to_json)
      expect(response).to have_http_status(:success)
    end

    it 'updates local subscription on successful payment' do
      # UserMailer#billing_email looks up the Stripe customer and card,
      # so the customer must exist in StripeMock.
      Stripe::Customer.create(
        id: subscription.customer_id,
        source: StripeMock.create_test_helper.generate_card_token
      )

      event = StripeMock.mock_webhook_event('invoice.payment_succeeded', {
        customer: subscription.customer_id
      })

      post_signed(event)

      expect(response).to have_http_status(:success)
      expect(subscription.reload.active_until).to eq 30.days.from_now
    end

    it 'notifies admins when a payment fails' do
      Fabricate(:user, role: User::ROLES[:admin])
      ActionMailer::Base.deliveries.clear

      event = StripeMock.mock_webhook_event('invoice.payment_failed', {
        customer: subscription.customer_id,
        billing_reason: 'subscription_cycle'
      })

      post_signed(event)

      expect(response).to have_http_status(:success)
      expect(ActionMailer::Base.deliveries).to_not be_empty
    end
  end
end
