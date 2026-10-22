require 'rails_helper'

RSpec.describe 'The EOI form wording and status, for staff', type: :request do
  let!(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027') }
  let(:lead) { admissions_staff(role: 'lead', user: Fabricate(:user, name: 'Test Lead')) }
  let(:officer) { admissions_staff(role: 'officer') }

  def notice_versions = Admissions::FormText.where(key: 'privacy_notice').order(:id)

  def write_notice(body)
    patch '/admissions/staff/wording/privacy_notice', params: { admissions_form_text: { body: body } }
  end

  describe 'a lead' do
    before { sign_in lead }

    it 'writes the privacy notice, which is kept as an attributed version and opens the form' do
      get '/admissions/staff'
      expect(response.body).to include('is closed and saves nothing')
      expect(response.body).to include('no privacy notice has been set')

      get '/admissions/staff/wording/privacy_notice/edit'
      expect(response).to have_http_status(:ok)
      write_notice("Test notice.\r\n\r\nTwo.")

      expect(response).to redirect_to('/admissions/staff/wording')
      expect(flash[:notice]).to eq 'Privacy notice saved. The form shows it from now on.'
      expect(notice_versions.sole).to have_attributes(body: "Test notice.\n\nTwo.", created_by_user: lead)

      get '/admissions/staff'
      expect(response.body).not_to include('is closed')
      expect(response.body).to include('is open. New expressions of interest join')
      get '/admissions'
      expect(response.body).to include('Test notice.')
    end

    it 'keeps every earlier version, and shows them' do
      write_notice('First test notice.')
      write_notice('Second test notice.')

      expect(notice_versions.map(&:body)).to eq ['First test notice.', 'Second test notice.']
      get '/admissions/staff/wording'
      expect(response.body).to include('Second test notice.', 'Earlier versions (1)', 'First test notice.',
                                       'Last changed', 'by Test Lead')
      expect(Admissions::EoiForm.privacy_notice.body).to eq 'Second test notice.'
    end

    it 'saves no version when nothing changed' do
      write_notice('Test notice.')
      write_notice(" Test notice.\n")

      expect(flash[:notice]).to eq 'Privacy notice: no change to save.'
      expect(notice_versions.count).to eq 1
    end

    it 'cannot blank the privacy notice, which would close the form' do
      write_notice('Test notice.')
      write_notice('  ')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(notice_versions.count).to eq 1
    end

    it 'writes and clears the introduction' do
      patch '/admissions/staff/wording/eoi_introduction', params: { admissions_form_text: { body: 'Test intro.' } }
      patch '/admissions/staff/wording/eoi_introduction', params: { admissions_form_text: { body: '' } }

      expect(Admissions::FormText.where(key: 'eoi_introduction').order(:id).map(&:body)).to eq ['Test intro.', '']
      expect(Admissions::FormText.text('eoi_introduction')).to be_nil
    end

    it 'finds no other wording to edit' do
      get '/admissions/staff/wording/something_else/edit'
      expect(response).to have_http_status(:not_found)
    end

    it 'is told when no round is open' do
      Admissions::FormText.create!(key: 'privacy_notice', body: 'Test notice.', created_by_user: lead)
      round.update!(closed_at: 1.day.ago)
      get '/admissions/staff'
      expect(response.body).to include('is closed and saves nothing', 'there is no open round')
      expect(response.body).not_to include('no privacy notice')
    end
  end

  describe 'an officer' do
    before { sign_in officer }

    it 'reads the wording and its history, but cannot change it' do
      Admissions::FormText.create!(key: 'privacy_notice', body: 'Test notice.', created_by_user: lead)

      get '/admissions/staff/wording'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Test notice.', 'Only an admissions lead can change them.')
      expect(response.body).not_to include('/admissions/staff/wording/privacy_notice/edit')

      get '/admissions/staff/wording/privacy_notice/edit'
      expect(response).to redirect_to('/admissions/staff')
      write_notice('Hijacked')
      expect(response).to redirect_to('/admissions/staff')
      expect(flash[:alert]).to eq 'Only an admissions lead can do that.'
      expect(notice_versions.map(&:body)).to eq ['Test notice.']
    end
  end

  describe 'everyone else gets the ordinary not-found at every staff path' do
    let(:email) do
      applicant = create_applicant(round: round)
      email_template(round, 'confirmation', subject: 'Test', body: 'Test body.')
      Admissions::EmailSender.request_automatic!(applicant, 'confirmation')
    end

    {
      'nobody signed in' => nil,
      'a member' => -> { Fabricate(:user) },
      'a site admin with no admissions role' => -> { Fabricate(:user, role: 'admin') }
    }.each do |who, make_user|
      it "for #{who}" do
        sign_in(instance_exec(&make_user)) if make_user
        applicant = email.applicant

        requests = [
          [:get, '/admissions/staff'],
          [:get, '/admissions/staff/wording'],
          [:get, '/admissions/staff/wording/privacy_notice/edit'],
          [:patch, '/admissions/staff/wording/privacy_notice', { admissions_form_text: { body: 'Hijacked' } }],
          [:get, "/admissions/staff/rounds/#{round.id}"],
          [:get, "/admissions/staff/rounds/#{round.id}/email_templates"],
          [:get, '/admissions/staff/emails'],
          [:patch, "/admissions/staff/emails/#{email.id}", { admissions_email: { subject: 'x', body: 'y' } }],
          [:post, "/admissions/staff/emails/#{email.id}/discard"],
          [:post, "/admissions/staff/applicants/#{applicant.id}/pause_emails"]
        ]
        requests.each do |verb, path, params|
          public_send(verb, path, params: params)
          expect(response).to have_http_status(:not_found), "#{verb.upcase} #{path} gave #{response.status}"
          expect(response.body).to include("The page you were looking for doesn't seem to be here")
        end

        expect(Admissions::FormText.count).to eq 0
        expect(email.reload).to be_held
        expect(applicant.reload.emails_paused).to be false
      end
    end

    it 'while the public form itself is open to all' do
      get '/admissions'
      expect(response).to have_http_status(:ok)
    end
  end
end
