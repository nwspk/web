require 'rails_helper'

RSpec.describe ConnectionsController, type: :controller do
  let(:user) { Fabricate(:user) }

  before do
    sign_in :user, user
  end

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #check_friends" do
    it "returns http success" do
      post :check_friends
      expect(response).to have_http_status(:redirect)
    end
  end
end
