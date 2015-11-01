require 'rails_helper'

RSpec.describe GraphsController, type: :controller do

  describe "GET #full" do
    it "returns http success" do
      get :full
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #friends" do
    it "returns http success" do
      sign_in :user, Fabricate(:user)
      get :friends
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #strangers" do
    it "returns http success" do
      sign_in :user, Fabricate(:user)
      get :strangers
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #access" do
    it "returns http success" do
      get :access
      expect(response).to have_http_status(:success)
    end
  end

end
