require 'rails_helper'

RSpec.describe ApiController, type: :controller do
  describe 'GET #uid' do
    # The api/uid route was removed in 547f12f (June 2022), so this action is
    # unreachable. Skipped pending a decision on deleting ApiController#uid and
    # the Ring door-access models, or restoring the route.
    before { skip 'api/uid route was removed in 2022; ApiController#uid is unrouted' }

    let(:user) { Fabricate(:user, subscription: Fabricate(:subscription, active_until: 30.days.from_now)) }
    let(:ring) { Fabricate(:ring, user: user, uid: 'foo') }

    it 'does not authorize a non-existing user' do
      get :uid, params: { uid: 'bar' }
      expect(response).to have_http_status(401)
    end

    it 'authorizes an existing user' do
      get :uid, params: { uid: ring.uid }
      expect(response).to have_http_status(:ok)
    end

    it 'records a door access event' do
      get :uid, params: { uid: ring.uid }
      expect(ring.door_accesses.count).to eq 1
    end
  end

  describe 'GET #events' do
    it 'renders an iCalendar feed' do
      get :events

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq 'text/calendar'
      expect(response.body).to include 'BEGIN:VCALENDAR'
      expect(response.body).to include 'Ration Club'
    end
  end
end
