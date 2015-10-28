require 'rails_helper'

RSpec.describe ConnectionsController, type: :controller do
  let(:user) { Fabricate(:user) }

  before do
    sign_in :user, user
  end

  describe "POST #check_friends" do
    it "returns http success" do
      mock(Resque).enqueue(CheckFriendsJob, user.id)

      post :check_friends

      expect(response).to have_http_status(:redirect)
    end
  end
end
