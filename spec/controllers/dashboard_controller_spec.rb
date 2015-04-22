require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  let(:user) { Fabricate(:user) }

  describe "GET #index" do
    it "returns http success" do
      sign_in :user, user
      get :index
      expect(response).to have_http_status(:success)
    end
  end

end
