require 'rails_helper'

RSpec.describe GraphsController, type: :controller do

  describe "GET #full" do
    before do
      get :full
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #friends" do
    before do
      sign_in :user, Fabricate(:user)
      get :friends
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #strangers" do
    before do
      sign_in :user, Fabricate(:user)
      get :strangers
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #access" do
    before do
      get :access
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end
  end

end
