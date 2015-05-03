require 'rails_helper'

RSpec.describe ApiController, type: :controller do
  describe 'GET #uid' do
    let(:user) { Fabricate(:user, subscription: Fabricate(:subscription, active_until: 30.days.from_now)) }
    let(:ring) { Fabricate(:ring, user: user, uid: 'foo') }

    it 'does not authorize a non-existing user' do
      get :uid, uid: 'bar'
      expect(response).to have_http_status(401)
    end

    it 'authorizes an existing user' do
      get :uid, uid: ring.uid
      expect(response).to have_http_status(:ok)
    end

    it 'records a door access event' do
      get :uid, uid: ring.uid
      expect(ring.door_accesses.count).to eq 1
    end
  end
end
