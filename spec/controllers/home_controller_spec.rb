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

    it "serves the form with both bot traps in place" do
      get :feedback
      expect(response.body).to include('name="served_at"')
      expect(response.body).to include(%(name="#{HomeController::FEEDBACK_HONEYPOT}"))
    end
  end

  describe "social preview tags" do
    render_views

    it "gives the house card to a page that sets no tags of its own" do
      get :feedback
      expect(response.body).to include('lcpt-roundel-social-card')
      expect(response.body).to include('The London College of Political Technology')
      expect(response.body).to include('twitter:card')
    end

    it "lets a page override just the title, keeping the shared card" do
      get :study_with_us
      expect(response.body).to include('Newspeak House Fellowship Programme')
      expect(response.body).to include('lcpt-roundel-social-card')
    end
  end

  describe "POST #submit_feedback" do
    let(:params) do
      { name: 'A Visitor', contact: 'visitor@example.com',
        incident: '2026-08-11T19:30', feedback: 'Lovely evening, projector was broken.' }
    end

    # Assert the mapping was applied, not what the mapping says — the entry.*
    # ids live in HomeController alone, so editing the Google Form is a
    # one-file change.
    let(:fields) { HomeController::FEEDBACK_FIELDS }

    it "relays the mapped fields to the Google Form and confirms" do
      expect(GoogleFormRelay).to receive(:submit) do |form_id, relayed|
        expect(form_id).to eq(HomeController::FEEDBACK_FORM_ID)
        expect(relayed[fields[:name]]).to eq('A Visitor')
        expect(relayed[fields[:contact]]).to eq('visitor@example.com')
        expect(relayed[fields[:feedback]]).to eq('Lovely evening, projector was broken.')
        expect(relayed["#{HomeController::FEEDBACK_INCIDENT_FIELD}_year"]).to eq('2026')
        expect(relayed["#{HomeController::FEEDBACK_INCIDENT_FIELD}_hour"]).to eq('19')
        true
      end
      post :submit_feedback, params: params
      expect(response).to redirect_to(feedback_path(sent: 'recorded'))
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "omits the incident fields when no date was given" do
      expect(GoogleFormRelay).to receive(:submit) do |_form_id, relayed|
        expect(relayed.keys.grep(/#{HomeController::FEEDBACK_INCIDENT_FIELD}/)).to be_empty
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
      expect(mail.to).to eq(['ed@newspeak.house'])
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

    describe "bot traps" do
      def stamp(time)
        Rails.application.message_verifier(:feedback_served_at).generate(time.to_i)
      end

      # A caught bot sees the same thank-you a person would, and nothing
      # reaches Google or the fallback inbox.
      def expect_caught(extra)
        expect(GoogleFormRelay).not_to receive(:submit)
        post :submit_feedback, params: params.merge(extra)
        expect(response).to redirect_to(feedback_path(sent: 'recorded'))
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "catches a submission that filled the honeypot" do
        expect_caught(HomeController::FEEDBACK_HONEYPOT => 'Cheap pills',
                      served_at: stamp(1.minute.ago))
      end

      it "catches a submission made the moment the form was served" do
        expect_caught(served_at: stamp(Time.current))
      end

      it "catches a forged served-at stamp" do
        expect_caught(served_at: 1.hour.ago.to_i.to_s)
      end

      it "relays a submission made a human interval after the form was served" do
        expect(GoogleFormRelay).to receive(:submit).and_return(true)
        post :submit_feedback, params: params.merge(served_at: stamp(10.seconds.ago))
        expect(response).to redirect_to(feedback_path(sent: 'recorded'))
      end
    end
  end
end
