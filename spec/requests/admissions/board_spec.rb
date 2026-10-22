require 'rails_helper'

RSpec.describe 'The admissions board and the staff home', type: :request do
  let!(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027', opens_on: Date.new(2026, 9, 1)) }
  let(:lead) { admissions_staff(role: 'lead', user: Fabricate(:user, name: 'Lead Person')) }
  let(:officer) { admissions_staff(role: 'officer', user: Fabricate(:user, name: 'Officer Person')) }

  def page = Nokogiri::HTML(response.body)
  def card(id) = "#card-#{id}"

  def expect_not_found
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("The page you were looking for doesn't seem to be here")
    expect(response.body).not_to include('Fellowship 2027')
  end

  describe 'anyone who is not admissions staff gets the ordinary not-found' do
    {
      'nobody signed in' => nil,
      'a member' => -> { Fabricate(:user) },
      'a site admin with no admissions role' => -> { Fabricate(:user, role: 'admin') }
    }.each do |who, make_user|
      it "for #{who}" do
        create_applicant(round: round)
        sign_in(instance_exec(&make_user)) if make_user

        get '/admissions/staff/board'
        expect_not_found
        get "/admissions/staff/board?round=#{round.id}"
        expect_not_found
        get '/admissions/staff/applicants?due=check_back'
        expect_not_found
        get '/admissions/staff/applicants?due=hold_return'
        expect_not_found
      end
    end
  end

  describe 'the board' do
    before { sign_in officer }

    it 'has a column per stage that is not terminal, in funnel order, then on hold and it\'s complicated' do
      get '/admissions/staff/board'
      expect(response).to have_http_status(:ok)
      columns = page.css('.admissions-board > section').map { |s| s['id'].delete_prefix('column-') }
      expect(columns).to eq %w[eoi invited applied task_sent task_returned interview_offered interview_booked
                               interviewed offered accepted contracts_sent on_hold complicated]
      expect(page.css('.admissions-board h3').map(&:text)).to start_with('EOI (0)', 'Invited (0)')
      expect(page.css('.admissions-board h3').map(&:text)).to end_with('On hold (0)', "It's complicated (0)")
    end

    it 'puts each applicant in one place: its stage, on hold, complicated, or the collapsed finished sections' do
      eoi = create_applicant(round: round, stage: 'eoi', name: nil, email: 'only.an.address@example.com')
      applied = create_applicant(round: round, stage: 'applied', name: 'Applied Person')
      held = applicant_at('on_hold', round: round)
      flagged = create_applicant(round: round, stage: 'task_sent')
      staff_changes.flag_complicated!(flagged, note: 'Waiting on a visa', check_back_on: Date.current + 3)
      flagged_on_hold = applicant_at('on_hold', round: round)
      staff_changes.flag_complicated!(flagged_on_hold, note: 'Both', check_back_on: Date.current + 3)
      confirmed = create_applicant(round: round, stage: 'confirmed')
      flagged_confirmed = create_applicant(round: round, stage: 'confirmed')
      staff_changes.flag_complicated!(flagged_confirmed, note: 'Visa trouble', check_back_on: Date.current + 3)
      deferred = applicant_at('deferred', round: round)
      withdrawn = applicant_at('withdrawn', round: round)
      elsewhere = create_applicant(round: Fabricate(:admissions_round, name: 'Another round'), stage: 'eoi')

      get '/admissions/staff/board'

      {
        'eoi' => [eoi], 'applied' => [applied], 'on_hold' => [held],
        'complicated' => [flagged, flagged_on_hold, flagged_confirmed]
      }.each do |column, applicants|
        expect(page.css("#column-#{column} .admissions-card").map { |c| c['id'] })
          .to eq(applicants.map { |a| "card-#{a.id}" }), column
      end
      expect(page.css('.admissions-board .admissions-card').size).to eq 6

      expect(page.at_css("#finished-confirmed:not([open]) #{card(confirmed.id)}")).to be_present
      expect(page.at_css("#finished-deferred #{card(deferred.id)}")).to be_present
      expect(page.at_css("#finished-withdrawn #{card(withdrawn.id)}").text)
        .to include("Withdrawn applicant ##{withdrawn.id}")
      expect(page.at_css('#finished-withdrawn summary').text).to eq 'Withdrawn (1)'
      expect(page.css('details.admissions-finished[open]')).to be_empty
      expect(page.at_css(card(elsewhere.id))).to be_nil

      # The card names the person once known, else their address; it opens the applicant's page.
      expect(page.at_css(card(eoi.id)).text).to include('only.an.address@example.com')
      expect(page.at_css(card(applied.id)).text).to include('Applied Person')
      expect(page.at_css(card(applied.id))['href']).to eq "/admissions/staff/applicants/#{applied.id}"
      expect(page.at_css(card(held.id)).text).to include('on hold from Applied', 'back')
      expect(page.at_css(card(flagged.id)).text).to include('Task sent', 'check back')
      expect(page.at_css(card(flagged_on_hold.id)).text).to include('Applied (on hold)')
    end

    it 'shows how long each card has sat in its stage, the longest first' do
      older = Timecop.travel(12.days.ago) { create_applicant(round: round, stage: 'applied') }
      newer = Timecop.travel(2.days.ago) { create_applicant(round: round, stage: 'applied') }

      get '/admissions/staff/board'
      expect(page.css('#column-applied .admissions-card').map { |c| c['id'] }).to eq ["card-#{older.id}",
                                                                                     "card-#{newer.id}"]
      expect(page.at_css(card(older.id)).text).to include('12 days in Applied')
      expect(page.at_css(card(newer.id)).text).to include('2 days in Applied')
    end

    it 'marks cards that are paused, have an email held for approval, or are due back' do
      email_template(round, 'confirmation')
      paused = create_applicant(round: round)
      staff_changes.pause_emails!(paused)
      held = create_applicant(round: round)
      Admissions::EmailSender.request_automatic!(held, 'confirmation')
      plain = create_applicant(round: round)
      due = create_applicant(round: round, stage: 'applied')
      staff_changes.flag_complicated!(due, note: 'Check soon', check_back_on: Date.current)

      get '/admissions/staff/board'
      expect(page.at_css("#{card(paused.id)} .admissions-card-markers").text).to include('Paused')
      expect(page.at_css("#{card(held.id)} .admissions-card-markers").text).to include('Held for approval')
      expect(page.at_css("#{card(plain.id)} .admissions-card-markers")).to be_nil
      expect(page.at_css("#{card(due.id)} .admissions-card-markers").text).to include('Check-back due')
    end

    it 'shows the round the EOI form fills unless another is chosen' do
      later = Fabricate(:admissions_round, name: 'Fellowship 2028', opens_on: Date.new(2027, 9, 1),
                                           invites_on: Date.new(2028, 2, 1), closes_on: Date.new(2028, 6, 30))
      mine = create_applicant(round: round)
      theirs = create_applicant(round: later)

      get '/admissions/staff/board'
      expect(page.at_css('h2').text).to eq 'Board: Fellowship 2027'
      expect(response.body).to include('The EOI form is filling this round.')
      expect(page.at_css(card(mine.id))).to be_present
      expect(page.at_css("select#round option[selected]").text).to eq 'Fellowship 2027'

      get "/admissions/staff/board?round=#{later.id}"
      expect(page.at_css('h2').text).to eq 'Board: Fellowship 2028'
      expect(response.body).not_to include('The EOI form is filling this round.')
      expect(page.at_css(card(theirs.id))).to be_present
      expect(page.at_css(card(mine.id))).to be_nil

      get '/admissions/staff/board?round=0'
      expect(response).to have_http_status(:not_found)
    end

    it 'falls back to the latest round when every round has closed, and copes with none' do
      Admissions::Round.update_all(closed_at: Time.current)
      get '/admissions/staff/board'
      expect(page.at_css('h2').text).to eq 'Board: Fellowship 2027'

      Admissions::Round.delete_all
      get '/admissions/staff/board'
      expect(response.body).to include('No rounds yet.')
    end
  end

  describe 'the staff home' do
    before { sign_in officer }

    it 'links to the board and the new-card form, and counts what is due' do
      due_check = create_applicant(round: round, stage: 'applied', name: 'Check Due')
      staff_changes.flag_complicated!(due_check, note: 'x', check_back_on: Date.current + 2)
      later_check = create_applicant(round: round, stage: 'applied', name: 'Check Later')
      staff_changes.flag_complicated!(later_check, note: 'x', check_back_on: Date.current + 9)
      due_hold = applicant_at('on_hold', round: round)
      staff_changes.update_details!(due_hold, name: 'Hold Due')
      later_hold = create_applicant(round: round, stage: 'applied', name: 'Hold Later')
      staff_changes.hold!(later_hold, until_date: Date.current + 30, reason: 'Later')

      Timecop.travel(Date.current + 14) do
        get '/admissions/staff'
        expect(response.body).to include('href="/admissions/staff/board"', 'href="/admissions/staff/applicants/new"')
        # Both check-backs are due, and the hold for 14 days.
        expect(page.at_css('a[href="/admissions/staff/applicants?due=check_back"]').text)
          .to eq "It's complicated: 2 due a check-back"
        expect(page.at_css('a[href="/admissions/staff/applicants?due=hold_return"]').text)
          .to eq 'On hold: 1 due to return'
      end

      Timecop.travel(Date.current + 5) do
        get '/admissions/staff'
        expect(page.at_css('a[href="/admissions/staff/applicants?due=check_back"]').text)
          .to eq "It's complicated: 1 due a check-back"
        expect(page.at_css('a[href="/admissions/staff/applicants?due=hold_return"]').text)
          .to eq 'On hold: 0 due to return'

        get '/admissions/staff/applicants?due=check_back'
        expect(page.text).to include("It's complicated: check-back date come", 'Check Due')
        expect(response.body).not_to include('Check Later')

        get '/admissions/staff/applicants?due=hold_return'
        expect(response.body).to include('On hold: return date come', 'Nobody, just now.')
      end

      Timecop.travel(Date.current + 14) do
        get '/admissions/staff/applicants?due=hold_return'
        expect(response.body).to include('Hold Due')
        expect(response.body).not_to include('Hold Later')
        expect(page.css('.admissions-card').map { |c| c['href'] }).to eq ["/admissions/staff/applicants/#{due_hold.id}"]
      end

      Timecop.travel(Date.current + 30) do
        get '/admissions/staff/applicants?due=hold_return'
        expect(page.css('.admissions-card').map { |c| c['href'] })
          .to eq ["/admissions/staff/applicants/#{due_hold.id}", "/admissions/staff/applicants/#{later_hold.id}"]
      end
    end

    it 'sends an unknown list to the board' do
      get '/admissions/staff/applicants'
      expect(response).to redirect_to('/admissions/staff/board')
    end
  end
end
