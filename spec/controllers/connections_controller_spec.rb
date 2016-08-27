require 'rails_helper'

RSpec.describe ConnectionsController, type: :controller do
  let(:user) { Fabricate(:user) }

  before do
    sign_in user, scope: :user
  end

  describe "POST #check_friends" do
    it "returns http success" do
      mock(CheckFriendsWorker).perform_async(user.id)

      post :check_friends

      expect(response).to have_http_status(:redirect)
    end
  end
end
