require 'rails_helper'

RSpec.describe SubscriptionsController, type: :controller do
  let(:user) { Fabricate(:user) }

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
    before do
      user.build_subscription(plan: Fabricate(:plan)).save
    end

    it "returns http success" do
      post :process_card, { stripeToken: StripeMock.generate_card_token(last4: "9191", exp_year: 1984) }
      expect(response).to have_http_status(:redirect)
    end
  end

end
