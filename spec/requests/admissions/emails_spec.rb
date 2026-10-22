require 'rails_helper'

RSpec.describe 'The approval queue, email templates and the pause switch', type: :request do
  let!(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027') }
  let(:lead) { admissions_staff(role: 'lead', user: Fabricate(:user, name: 'Lead Person')) }
  let(:officer) { admissions_staff(role: 'officer', user: Fabricate(:user, name: 'Officer Person')) }
  let!(:applicant) { create_applicant(round: round, name: 'Test Person', email: 'test.person@example.com') }
  let!(:template) { email_template(round, 'confirmation') }
  let!(:email) { Admissions::EmailSender.request_automatic!(applicant, 'confirmation') }

  def expect_not_found
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("The page you were looking for doesn't seem to be here")
    expect(response.body).not_to include('Test Person')
  end

  describe 'anyone who is not admissions staff gets the ordinary not-found' do
    {
      'nobody signed in' => nil,
      'a member' => -> { Fabricate(:user) },
      'a site admin with no admissions role' => -> { Fabricate(:user, role: 'admin') }
    }.each do |who, make_user|
      it "for #{who}, and nothing changes" do
        sign_in(instance_exec(&make_user)) if make_user

        get '/admissions/staff/emails'
        expect_not_found
        patch "/admissions/staff/emails/#{email.id}", params: { admissions_email: { subject: 'Hijacked', body: 'x' },
                                                          send_email: '1' }
        expect_not_found
        post "/admissions/staff/emails/#{email.id}/discard"
        expect_not_found
        post "/admissions/staff/applicants/#{applicant.id}/pause_emails"
        expect_not_found
        get "/admissions/staff/rounds/#{round.id}/email_templates"
        expect_not_found
        get "/admissions/staff/rounds/#{round.id}/email_templates/new?email_type=holding"
        expect_not_found
        post "/admissions/staff/rounds/#{round.id}/email_templates",
             params: { admissions_email_template: { email_type: 'holding', subject: 's', body: 'b' } }
        expect_not_found
        patch "/admissions/staff/rounds/#{round.id}/email_templates/#{template.id}",
              params: { admissions_email_template: { subject: 'Hijacked' } }
        expect_not_found

        expect(email.reload).to have_attributes(status: 'held', subject: 'Test subject for Test Person')
        expect(applicant.reload.emails_paused).to be false
        expect(template.reload.subject).to eq 'Test subject for {{name}}'
        expect(round.email_templates.count).to eq 1
        expect(recorded_emails).to be_empty
      end
    end
  end

  describe 'the queue' do
    before { sign_in officer }

    it 'lists every held email with its applicant, type, when drafted and full text' do
      other = create_applicant(round: round, name: 'Gone Person')
      staff_sender(lead).discard!(Admissions::EmailSender.request_automatic!(other, 'confirmation'))

      get '/admissions/staff/emails'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Approval queue', 'EOI confirmation to Test Person', 'test.person@example.com',
                                       'Fellowship 2027', 'Drafted', 'by the system',
                                       'Test subject for Test Person', 'Test body, Test Person, for Fellowship 2027.')
      expect(response.body).not_to include('Gone Person')
    end

    it 'is linked from the admissions home with its count' do
      get '/admissions/staff'
      expect(response.body).to include('Approval queue (1 email waiting)')
    end

    it 'saves edits, attributed, without sending' do
      patch "/admissions/staff/emails/#{email.id}", params: { admissions_email: { subject: 'New subject', body: "New\r\nbody" } }
      expect(response).to redirect_to("/admissions/staff/emails#email-#{email.id}")
      follow_redirect!
      expect(response.body).to include('Changes saved. The email is still waiting to be sent.')

      expect(email.reload).to have_attributes(status: 'held', subject: 'New subject', body: "New\nbody",
                                              edited_by_user: officer)
      expect(applicant.events.where(kind: 'email_edited').sole)
        .to have_attributes(actor_user: officer, body: "Subject: New subject\n\nNew\nbody")
      expect(recorded_emails).to be_empty
    end

    it 'sends the text as shown, saving any edits first' do
      patch "/admissions/staff/emails/#{email.id}", params: { admissions_email: { subject: 'Final subject', body: 'Final body' },
                                                        send_email: 'Send' }
      expect(response).to redirect_to('/admissions/staff/emails')
      follow_redirect!
      expect(response.body).to include('Sent to test.person@example.com.', 'Nothing is waiting.')

      expect(email.reload).to be_sent
      expect(email.sent_by_user).to eq officer
      expect(recorded_emails.map { |m| [m.to, m.subject, m.body] })
        .to eq [['test.person@example.com', 'Final subject', 'Final body']]
      expect(applicant.events.where(kind: %w[email_edited email_sent]).map { |e| [e.kind, e.actor_user] })
        .to eq [['email_edited', officer], ['email_sent', officer]]
    end

    it 'keeps what was typed when an edit is refused' do
      patch "/admissions/staff/emails/#{email.id}", params: { admissions_email: { subject: '', body: 'My careful rewrite' },
                                                        send_email: 'Send' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Not saved: Subject can&#39;t be blank.', 'My careful rewrite')
      expect(email.reload).to be_held
      expect(recorded_emails).to be_empty
    end

    it 'says so, and keeps the email, when sending fails' do
      Admissions::Delivery.adapter = Class.new do
        def deliver(_) = raise(Admissions::Delivery::NotConfigured, 'Gmail delivery is not configured: set X in the environment')
      end.new
      patch "/admissions/staff/emails/#{email.id}", params: { admissions_email: { subject: email.subject, body: email.body },
                                                        send_email: 'Send' }
      follow_redirect!
      expect(response.body).to include('Not sent, and still waiting: Gmail delivery is not configured: set X in the environment.')
      expect(response.body).to include('Save changes')
      expect(email.reload).to be_held
    ensure
      Admissions::Delivery.adapter = nil
    end

    it 'discards, attributed' do
      post "/admissions/staff/emails/#{email.id}/discard"
      follow_redirect!
      expect(response.body).to include('Email discarded. It will not be sent.')
      expect(email.reload).to be_discarded
      expect(email.discarded_by_user).to eq officer
      expect(applicant.events.where(kind: 'email_discarded').sole.actor_user).to eq officer
    end

    it 'refuses to act twice on the same email' do
      post "/admissions/staff/emails/#{email.id}/discard"
      patch "/admissions/staff/emails/#{email.id}", params: { admissions_email: { subject: 's', body: 'b' }, send_email: 'Send' }
      follow_redirect!
      expect(response.body).to include('Nothing done: this email has already been discarded.')
      expect(recorded_emails).to be_empty
    end

    it 'says when this site only records mail' do
      get '/admissions/staff/emails'
      expect(response.body).to include('Recording only: nothing is actually sent from this site.')

      allow(Admissions::Delivery).to receive(:recording?).and_return(false)
      get '/admissions/staff/emails'
      expect(response.body).not_to include('Recording only')
    end

    describe 'a send whose outcome is unknown' do
      before do
        Admissions::Delivery.adapter = Class.new do
          def deliver(_) = raise(Admissions::Delivery::OutcomeUnknown, 'the connection to Gmail was lost before it answered')
        end.new
        patch "/admissions/staff/emails/#{email.id}", params: { admissions_email: { subject: email.subject, body: email.body },
                                                          send_email: 'Send' }
        Admissions::Delivery.adapter = nil
      end

      it 'says so, shows the text, and offers only the two resolutions' do
        follow_redirect!
        expect(response.body).to include(
          'Outcome unknown: check the admissions@ Sent folder (the connection to Gmail was lost before it answered).'
        )
        expect(response.body).to include('Outcome unknown: check the admissions@ Sent folder.', 'It was sent',
                                         'It wasn&#39;t sent: put it back in the queue', 'Test subject for Test Person')
        expect(response.body).not_to include('Save changes')
      end

      it 'is resolved as sent, attributed' do
        post "/admissions/staff/emails/#{email.id}/confirm_sent"
        follow_redirect!
        expect(response.body).to include('Recorded as sent.')
        expect(email.reload).to be_sent
        expect(applicant.events.where(kind: 'email_sent').sole.actor_user).to eq officer
      end

      it 'is resolved as not sent, back in the queue' do
        post "/admissions/staff/emails/#{email.id}/confirm_not_sent"
        follow_redirect!
        expect(response.body).to include('Recorded as not sent. The email is back in the queue.', 'Save changes')
        expect(email.reload).to be_held
      end
    end

    it 'shows a send in progress without offering anything' do
      crash = Class.new(Exception) # rubocop:disable Lint/InheritException
      Admissions::Delivery.adapter = Class.new { define_method(:deliver) { |_| raise crash } }.new
      expect { staff_sender(officer).send_held!(email) }.to raise_error(crash) # the process died mid-send
      Admissions::Delivery.adapter = nil
      get '/admissions/staff/emails'
      expect(response.body).to include('Sending…')
      expect(response.body).not_to include('It was sent', 'Save changes')
      post "/admissions/staff/emails/#{email.id}/confirm_sent"
      follow_redirect!
      expect(response.body).to include('Nothing done: this email is still being sent.')
    end

    it 'is not found for an email that does not exist' do
      post '/admissions/staff/emails/0/discard'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'the pause switch' do
    before { sign_in officer }

    it 'turns automatic email to one applicant off and on, each attributed' do
      post "/admissions/staff/applicants/#{applicant.id}/pause_emails"
      follow_redirect!
      expect(response.body).to include('Automatic email to Test Person is paused.', 'Resume automatic email')
      expect(applicant.reload.emails_paused).to be true

      post "/admissions/staff/applicants/#{applicant.id}/resume_emails"
      follow_redirect!
      expect(response.body).to include('Automatic email to Test Person is back on.')
      expect(applicant.reload.emails_paused).to be false

      expect(applicant.events.where(kind: %w[emails_paused emails_resumed]).map { |e| [e.kind, e.actor_user] })
        .to eq [['emails_paused', officer], ['emails_resumed', officer]]
    end

    it 'says when there is nothing to do' do
      post "/admissions/staff/applicants/#{applicant.id}/resume_emails"
      follow_redirect!
      expect(response.body).to include('Nothing done: automatic email to this applicant is not paused.')
    end
  end

  describe 'email templates' do
    it 'are listed for any staff member, and written only by a lead' do
      sign_in officer
      get "/admissions/staff/rounds/#{round.id}/email_templates"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Test subject for {{name}}', 'No template yet', 'Only an admissions lead can change them.')
      expect(response.body).not_to include('Write it')

      get "/admissions/staff/rounds/#{round.id}/email_templates/#{template.id}/edit"
      expect(response).to redirect_to('/admissions/staff')
      patch "/admissions/staff/rounds/#{round.id}/email_templates/#{template.id}",
            params: { admissions_email_template: { subject: 'Officer rewrite' } }
      expect(template.reload.subject).to eq 'Test subject for {{name}}'
      post "/admissions/staff/rounds/#{round.id}/email_templates",
           params: { admissions_email_template: { email_type: 'holding', subject: 's', body: 'b' } }
      expect(round.email_templates.count).to eq 1
    end

    it 'are written by a lead, attributed, and then draftable' do
      sign_in lead
      get "/admissions/staff/rounds/#{round.id}/email_templates/new?email_type=holding"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Holding email (EOI out of round) template', '{{portal_link}}')

      post "/admissions/staff/rounds/#{round.id}/email_templates",
           params: { admissions_email_template: { email_type: 'holding', subject: 'Fake holding subject',
                                                  body: "Fake holding body for {{name}}\r\nLine two" } }
      expect(response).to redirect_to("/admissions/staff/rounds/#{round.id}/email_templates")
      created = round.email_template('holding')
      expect(created).to have_attributes(body: "Fake holding body for {{name}}\nLine two", updated_by_user: lead)

      patch "/admissions/staff/rounds/#{round.id}/email_templates/#{template.id}",
            params: { admissions_email_template: { subject: 'Edited {{round}}' } }
      expect(template.reload.subject).to eq 'Edited {{round}}'
      expect(template.updated_by_user).to eq lead
    end

    it 'refuse unknown placeholders, saying which' do
      sign_in lead
      post "/admissions/staff/rounds/#{round.id}/email_templates",
           params: { admissions_email_template: { email_type: 'holding', subject: 'Hi {{first_name}}', body: 'b' } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('uses unknown placeholders: {{first_name}}')
    end

    it 'are not found for an unknown type' do
      sign_in lead
      get "/admissions/staff/rounds/#{round.id}/email_templates/new?email_type=love_letter"
      expect(response).to have_http_status(:not_found)
    end
  end
end
