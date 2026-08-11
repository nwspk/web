require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #feedback" do
    render_views

    it "renders the native feedback form" do
      get :feedback
      expect(response).to have_http_status(:success)
      expect(response.body).to include('feedback-form')
    end
  end

  describe "POST #submit_feedback" do
    let(:params) do
      { name: 'A Visitor', contact: 'visitor@example.com',
        incident: '2026-08-11T19:30', feedback: 'Lovely evening, projector was broken.' }
    end

    it "relays the mapped fields to the Google Form and confirms" do
      expect(GoogleFormRelay).to receive(:submit) do |form_id, fields, confirmation:|
        expect(form_id).to eq(HomeController::FEEDBACK_FORM_ID)
        expect(fields['entry.715514050']).to eq('A Visitor')
        expect(fields['entry.503492203']).to eq('visitor@example.com')
        expect(fields['entry.2137140456']).to eq('Lovely evening, projector was broken.')
        expect(fields['entry.48862705_year']).to eq('2026')
        expect(fields['entry.48862705_month']).to eq('8')
        expect(fields['entry.48862705_hour']).to eq('19')
        expect(confirmation).to be_a(String)
        true
      end
      post :submit_feedback, params: params
      expect(response).to redirect_to(feedback_path(sent: 'recorded'))
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "omits the incident fields when no date was given" do
      expect(GoogleFormRelay).to receive(:submit) do |_form_id, fields, confirmation:|
        expect(fields.keys.grep(/48862705/)).to be_empty
        true
      end
      post :submit_feedback, params: params.merge(incident: '')
      expect(response).to redirect_to(feedback_path(sent: 'recorded'))
    end

    it "captures the submission by email when Google does not confirm" do
      allow(GoogleFormRelay).to receive(:submit).and_return(false)
      post :submit_feedback, params: params
      expect(response).to redirect_to(feedback_path(sent: 'emailed'))
      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to include('relay failed')
      expect(mail.body.encoded).to include('Lovely evening')
      expect(mail.body.encoded).to include('visitor@example.com')
    end

    it "drops submissions missing required fields without relaying or emailing" do
      expect(GoogleFormRelay).not_to receive(:submit)
      post :submit_feedback, params: params.merge(feedback: '  ')
      expect(response).to redirect_to(feedback_path)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
