require 'rails_helper'

RSpec.describe EventsController, type: :controller do
  render_views

  describe 'GET #index' do
    let(:past_event)     { Fabricate(:event, name: 'Past event') }
    let(:upcoming_event) { Fabricate(:event, name: 'Upcoming event', start_at: 1.day.from_now, end_at: 1.day.from_now + 2.hours) }
    let(:private_event)  { Fabricate(:event, name: 'Private event', public: false) }

    it 'renders generic social-preview tags without a selected event' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.body).to include 'Upcoming Events at Newspeak House'
      expect(response.body).to include 'lcpt-roundel-social-card'
    end

    it 'renders social-preview tags for an upcoming event selected by id' do
      get :index, params: { id: upcoming_event.id }
      expect(response.body).to include "events?id=#{upcoming_event.id}"
      expect(response.body).to include 'hosted by Foo at Newspeak House'
      expect(response.body).to include 'lcpt-roundel-social-card'
    end

    it 'renders social-preview tags for a past event, so shared links outlive the event' do
      get :index, params: { id: past_event.id }
      expect(response.body).to include "events?id=#{past_event.id}"
      expect(response.body).to include 'hosted by Foo at Newspeak House'
    end

    it 'falls back to generic tags for a non-public event id' do
      get :index, params: { id: private_event.id }
      expect(response.body).to include 'Upcoming Events at Newspeak House'
      expect(response.body).not_to include 'Private event'
    end
  end
end
