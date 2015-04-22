require 'rails_helper'

RSpec.describe SubscriptionsController, type: :controller do
  let(:user) { Fabricate(:user) }

  describe "GET #checkout" do
    it "returns http success" do
      sign_in :user, user
      get :checkout
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #process_card" do
    it "returns http success" do
      pending
    end
  end

end
