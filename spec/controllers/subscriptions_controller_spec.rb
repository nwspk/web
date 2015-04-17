require 'rails_helper'

RSpec.describe SubscriptionController, type: :controller do

  describe "GET #checkout" do
    it "returns http success" do
      get :checkout
      expect(response).to have_http_status(:success)
    end
  end

end
