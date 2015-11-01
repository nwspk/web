require 'rails_helper'

RSpec.describe SubscriptionsController, type: :controller do
  let(:user) { Fabricate(:subscription).user }

  before do
    sign_in :user, user
  end

  describe "GET #checkout" do
    it "returns http success" do
      get :checkout
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #process_card" do
    let(:plan) { Fabricate(:plan, value: 5000) }

    before do
      user.build_subscription(plan: plan).save
    end

    it "returns http success" do
      post :process_card, { stripeToken: StripeMock.generate_card_token(last4: "9191", exp_year: 1984) }
      expect(response).to have_http_status(:redirect)
    end

    it "charges user only sign-up fee first" do
      token = StripeMock.generate_card_token(last4: "9191", exp_year: 1984)

      mock.proxy(Stripe::Customer).create.with_any_args do |customer|
        expect(customer.account_balance).to eq (SIGNUP_FEE - 5000)
        customer
      end

      post :process_card, { stripeToken: token }
    end
  end

end
