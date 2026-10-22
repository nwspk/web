require 'rails_helper'

RSpec.describe 'The /admissions area', type: :request do
  let!(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027') }
  let(:lead) { admissions_staff(role: 'lead') }
  let(:officer) { admissions_staff(role: 'officer') }

  def expect_not_found
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("The page you were looking for doesn't seem to be here")
    expect(response.body).not_to include('Fellowship 2027')
  end

  describe 'anyone who is not admissions staff gets the ordinary not-found' do
    {
      'nobody signed in' => nil,
      'a member' => -> { Fabricate(:user) },
      'site staff' => -> { Fabricate(:user, role: 'staff') },
      'a site admin with no admissions role' => -> { Fabricate(:user, role: 'admin') }
    }.each do |who, make_user|
      it "for #{who}" do
        sign_in(instance_exec(&make_user)) if make_user

        get '/admissions'
        expect_not_found
        get "/admissions/rounds/#{round.id}"
        expect_not_found
        get "/admissions/rounds/#{round.id}/edit"
        expect_not_found
        get '/admissions/rounds/new'
        expect_not_found
        patch "/admissions/rounds/#{round.id}", params: { admissions_round: { name: 'Hijacked' } }
        expect_not_found
        post '/admissions/rounds', params: { admissions_round: { name: 'Sneaky' } }
        expect_not_found

        expect(round.reload.name).to eq 'Fellowship 2027'
        expect(Admissions::Round.count).to eq 1
      end
    end

    it 'looks the same as a page that does not exist' do
      get '/admissions'
      admissions_body = response.body
      get '/no-such-page'
      expect(response.body).to eq admissions_body
    end
  end

  describe 'an officer' do
    before { sign_in officer }

    it 'sees the rounds with applicant counts per stage' do
      create_applicant(round: round, stage: 'applied')
      create_applicant(round: round, stage: 'applied')
      flagged = create_applicant(round: round, stage: 'eoi')
      staff_changes.flag_complicated!(flagged, note: 'n', check_back_on: Date.current)

      get '/admissions'
      expect(response).to have_http_status(:ok)
      body = Nokogiri::HTML(response.body)
      counts = body.css('table.admissions-stage-counts tbody tr').to_h { |tr| tr.css('td').map(&:text) }
      expect(counts).to include('Applied' => '2', 'EOI' => '1', 'Confirmed' => '0', "It's complicated" => '1')
      expect(response.body).not_to include('New round')
    end

    it 'reads the settings but is offered no edit' do
      get "/admissions/rounds/#{round.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Programme fee', 'Ask me first', 'Staff turnaround: Applied')
      expect(response.body).not_to include('Edit settings')
    end

    it 'cannot edit or create' do
      get "/admissions/rounds/#{round.id}/edit"
      expect(response).to redirect_to('/admissions')
      expect(flash[:alert]).to eq 'Only an admissions lead can do that.'

      patch "/admissions/rounds/#{round.id}", params: { admissions_round: { name: 'Renamed' } }
      expect(response).to redirect_to('/admissions')
      expect(round.reload.name).to eq 'Fellowship 2027'

      post '/admissions/rounds', params: { admissions_round: { name: 'Another' } }
      expect(Admissions::Round.count).to eq 1
    end
  end

  describe 'a lead' do
    before { sign_in lead }

    it 'edits the settings' do
      get "/admissions/rounds/#{round.id}/edit"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Programme fee (£)', 'Reminder interval (days)', 'Weekly reminder')

      patch "/admissions/rounds/#{round.id}", params: { admissions_round: {
        programme_fee_pounds: '3,000', accommodation_monthly_pounds: '1100.50', scholarship_pot_pounds: '',
        reminder_interval_days: '10',
        staff_turnaround_days: { 'applied' => '3', 'interviewed' => '' },
        email_modes: { 'confirmation' => 'automatic', 'reminder' => 'off' }
      } }
      expect(response).to redirect_to("/admissions/rounds/#{round.id}")
      expect(flash[:notice]).to eq 'Round settings saved.'

      round.reload
      expect(round.programme_fee).to eq Money.new(300_000, 'GBP')
      expect(round.accommodation_monthly_pence).to eq 110_050
      expect(round.scholarship_pot).to be_nil
      expect(round.reminder_interval).to eq 10.days
      expect(round.staff_turnaround('applied')).to eq 3.days
      expect(round.staff_turnaround('interviewed')).to eq 7.days
      expect(round.email_mode('confirmation')).to eq 'automatic'
      expect(round.email_mode('reminder')).to eq 'off'
      expect(round.email_mode('holding')).to eq 'ask_me_first'

      get "/admissions/rounds/#{round.id}"
      expect(response.body).to include('Edit settings', '£3000.00', '10 days')
    end

    it 'sees errors and keeps what was typed' do
      patch "/admissions/rounds/#{round.id}", params: { admissions_round: {
        programme_fee_pounds: 'lots', reminder_interval_days: '0',
        staff_turnaround_days: { 'applied' => 'soon' }, email_modes: { 'confirmation' => 'sometimes' }
      } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('must be an amount in pounds', 'lots', 'unknown modes: sometimes',
                                       'must be whole days between 1 and 365')
      expect(round.reload.programme_fee_pence).to be_nil
    end

    it 'ignores email types and stages that are not in the lists' do
      patch "/admissions/rounds/#{round.id}", params: { admissions_round: {
        email_modes: { 'made_up' => 'automatic' }, staff_turnaround_days: { 'invited' => '2' }
      } }
      expect(round.reload.email_modes).to eq({})
      expect(round.staff_turnaround_days).to eq({})
    end

    it 'creates a round' do
      get '/admissions'
      expect(response.body).to include('New round')
      get '/admissions/rounds/new'
      expect(response).to have_http_status(:ok)

      post '/admissions/rounds', params: { admissions_round: { name: 'Fellowship 2028', opens_on: '2027-09-01' } }
      created = Admissions::Round.find_by!(name: 'Fellowship 2028')
      expect(response).to redirect_to("/admissions/rounds/#{created.id}")
      expect(created.opens_on).to eq Date.new(2027, 9, 1)
      expect(created.email_mode('offer')).to eq 'ask_me_first'
    end

    it 'gets a not-found for a round that does not exist' do
      get '/admissions/rounds/0'
      expect(response).to have_http_status(:not_found)
    end
  end
end
