require 'rails_helper'

RSpec.describe SubscriptionsController, type: :controller do
  let(:user) { Fabricate(:subscription).user }

  before do
    sign_in user, scope: :user
  end

  describe "GET #checkout" do
    it "returns http success" do
      get :checkout
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #process_card" do
    it "rejects a checkout session that belongs to another account" do
      checkout = Stripe::StripeObject.construct_from(
        customer_email: 'someone-else@example.com',
        customer: 'cus_123',
        subscription: 'sub_123'
      )
      allow(Stripe::Checkout::Session).to receive(:retrieve).with('cs_123').and_return(checkout)

      post :process_card, params: { session_id: 'cs_123' }

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to match(/does not belong to your account/)
      expect(user.subscription.reload.customer_id).to_not eq 'cus_123'
    end

    it "activates the subscription from a matching checkout session" do
      checkout = Stripe::StripeObject.construct_from(
        customer_email: user.email,
        customer: 'cus_123',
        subscription: 'sub_123'
      )
      stripe_subscription = Stripe::StripeObject.construct_from(
        id: 'sub_123',
        current_period_end: 30.days.from_now.to_i
      )
      allow(Stripe::Checkout::Session).to receive(:retrieve).with('cs_123').and_return(checkout)
      allow(Stripe::Subscription).to receive(:retrieve).with('sub_123').and_return(stripe_subscription)

      post :process_card, params: { session_id: 'cs_123' }

      expect(response).to redirect_to(dashboard_path)
      expect(user.subscription.reload.customer_id).to eq 'cus_123'
      expect(user.subscription.subscription_id).to eq 'sub_123'
      expect(user.subscription.active_until).to be > Time.current
    end
  end

end
