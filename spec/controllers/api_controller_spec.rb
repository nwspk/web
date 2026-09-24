require 'rails_helper'

RSpec.describe ApiController, type: :controller do
  describe 'GET #events' do
    it 'renders an iCalendar feed' do
      get :events

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq 'text/calendar'
      expect(response.body).to include 'BEGIN:VCALENDAR'
      expect(response.body).to include 'Ration Club'
    end

    it 'carries recent and upcoming events but not the deep archive' do
      Fabricate(:event, name: 'Recent event',   start_at: 1.month.ago,  end_at: 1.month.ago + 2.hours)
      Fabricate(:event, name: 'Upcoming event', start_at: 1.week.from_now, end_at: 1.week.from_now + 2.hours)
      Fabricate(:event, name: 'Archived event', start_at: 2.years.ago,  end_at: 2.years.ago + 2.hours)

      get :events

      expect(response.body).to include 'Recent event'
      expect(response.body).to include 'Upcoming event'
      expect(response.body).not_to include 'Archived event'
    end
  end
end
