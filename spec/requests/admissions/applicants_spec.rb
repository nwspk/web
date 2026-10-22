require 'rails_helper'

RSpec.describe "The applicant's page, its actions, and cards created by hand", type: :request do
  let!(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027') }
  let(:lead) { admissions_staff(role: 'lead', user: Fabricate(:user, name: 'Lead Person')) }
  let(:officer) { admissions_staff(role: 'officer', user: Fabricate(:user, name: 'Officer Person')) }
  let!(:applicant) do
    create_applicant(round: round, name: 'Test Person', email: 'test.person@example.com', phone: '07700 900123')
  end

  def page = Nokogiri::HTML(response.body)
  def text = page.text.squish
  def path(suffix = '') = "/admissions/staff/applicants/#{applicant.id}#{suffix}"
  def kinds = applicant.events.reorder(:id).pluck(:kind)
  def last_event = applicant.events.reorder(:id).last

  # A delivery that sends for real, as far as the email-sender can tell.
  def gmail_like
    Class.new do
      def deliver(_message) = Admissions::Delivery::Receipt.new(delivery: 'gmail', message_id: 'gmail-1')
    end.new
  end

  def expect_not_found
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("The page you were looking for doesn't seem to be here")
    expect(response.body).not_to include('Test Person')
  end

  describe 'anyone who is not admissions staff gets the ordinary not-found, and nothing changes' do
    {
      'nobody signed in' => nil,
      'a member' => -> { Fabricate(:user) },
      'a site admin with no admissions role' => -> { Fabricate(:user, role: 'admin') }
    }.each do |who, make_user|
      it "for #{who}" do
        sign_in(instance_exec(&make_user)) if make_user
        before = kinds

        get path
        expect_not_found
        get path('/move?to=applied')
        expect_not_found
        get path('/withdraw')
        expect_not_found
        get '/admissions/staff/applicants/new'
        expect_not_found
        post '/admissions/staff/applicants', params: { card: { round_id: round.id, email: 'new@example.com' },
                                                      create: '1' }
        expect_not_found
        {
          '/note' => { body: 'Sneaky' },
          '/pause_emails' => {},
          '/resume_emails' => {},
          '/flag_complicated' => { note: 'x', check_back_on: Date.current.iso8601 },
          '/clear_complicated' => {},
          '/hold' => { hold_until: (Date.current + 9).iso8601, reason: 'x' },
          '/return_from_hold' => {},
          '/move' => { to: 'applied' },
          '/defer' => {},
          '/reopen' => {},
          '/withdraw' => { confirm: '1' }
        }.each do |action, params|
          post path(action), params: params
          expect_not_found
        end

        expect(kinds).to eq before
        expect(applicant.reload).to have_attributes(stage: 'eoi', email: 'test.person@example.com')
        expect(Admissions::Applicant.count).to eq 1
      end
    end
  end

  describe 'details' do
    before { sign_in officer }

    it 'shows email, phone, stage, time in stage, the round, and the earlier-round record' do
      earlier_round = Fabricate(:admissions_round, name: 'Fellowship 2026', opens_on: Date.new(2025, 9, 1),
                                                   invites_on: Date.new(2026, 2, 1), closes_on: Date.new(2026, 6, 30))
      earlier = create_applicant(round: earlier_round, name: 'Test Person', email: 'test.person@example.com')
      later_round = Fabricate(:admissions_round, name: 'Fellowship 2028', opens_on: Date.new(2027, 9, 1),
                                                 invites_on: Date.new(2028, 2, 1), closes_on: Date.new(2028, 6, 30))
      returning = Timecop.travel(5.days.ago) do
        staff_changes.create!(round: later_round, email: 'test.person@example.com', name: 'Test Person',
                              stage: 'applied', previous_applicant: earlier)
      end

      get "/admissions/staff/applicants/#{returning.id}"
      expect(response).to have_http_status(:ok)
      details = page.at_css('table.admissions-details').text.squish
      expect(details).to include('Email test.person@example.com', 'Phone Not given', 'Name Test Person',
                                 'Stage Applied', 'Time in stage 5 days', 'Round Fellowship 2028',
                                 'Earlier round Fellowship 2026: Test Person',
                                 'Next step Staff to review the application and send the task, due')
      expect(page.at_css("a[href='/admissions/staff/applicants/#{earlier.id}']")).to be_present

      get "/admissions/staff/applicants/#{earlier.id}"
      expect(page.at_css('table.admissions-details').text.squish).to include('Other rounds Fellowship 2028: Applied')
    end

    it 'shows the hold, the flag and the first-interest date' do
      back = Date.current + 40
      check = Date.current + 30
      staff_changes.hold!(applicant, until_date: back, reason: 'Exams')
      staff_changes.flag_complicated!(applicant, note: 'Two applications', check_back_on: check)

      get path
      details = page.at_css('table.admissions-details').text.squish
      expect(details).to include("On hold from EOI, until #{I18n.l(back, format: :long)}",
                                 "It's complicated: check back #{I18n.l(check, format: :long)}",
                                 "First expressed interest #{I18n.l(Date.current, format: :long)}")
      expect(details).not_to include('entered by hand')
    end
  end

  describe 'correspondence, built from the event log' do
    before do
      sign_in officer
      email_template(round, 'confirmation', subject: 'Welcome {{name}}', body: "Hello {{name}}.\nSee you.")
      email_template(round, 'holding', subject: 'Holding', body: 'We start in February.')
    end

    it 'shows every email sent, newest first, with type, date, who sent it and the exact text' do
      Timecop.travel(2.days.ago) do
        Admissions::EmailSender.new(Admissions::Actor.system, delivery: gmail_like)
                               .request_automatic!(applicant, 'confirmation')
      end
      round.update!(email_modes: { 'confirmation' => 'automatic' })
      held = Admissions::EmailSender.request_automatic!(applicant, 'holding')
      Admissions::EmailSender.new(Admissions::Actor.staff(lead), delivery: gmail_like).send_held!(held)

      get path
      section = page.css('.admissions-sent-email')
      expect(section.size).to eq 1
      expect(section.first.text.squish).to include('Holding email (EOI out of round)', 'Sent by Lead Person.',
                                                    'Subject: Holding', 'We start in February.')

      # The confirmation was asked-me-first, so held; once sent it shows.
      Admissions::EmailSender.new(Admissions::Actor.staff(officer), delivery: gmail_like)
                             .send_held!(applicant.emails.find_by(email_type: 'confirmation'))
      get path
      headings = page.css('.admissions-sent-email h4').map { |h| h.text.squish }
      expect(headings.first).to start_with('EOI confirmation')
      expect(headings.second).to start_with('Holding email')
      expect(page.css('.admissions-sent-email').first.text).to include("Hello Test Person.\nSee you.")
      expect(text).not_to include('Recording only')
      expect(text).to include("Replies to admissions@ aren't shown here yet.")
    end

    it 'says when a send was only recorded, and when an automatic one went' do
      round.update!(email_modes: { 'confirmation' => 'automatic' })
      Admissions::EmailSender.request_automatic!(applicant, 'confirmation')

      get path
      expect(page.at_css('.admissions-sent-email').text.squish)
        .to include('Sent automatically.', 'Recording only: nothing actually went out.')
    end

    it 'shows an email staff confirmed sent from the Sent folder' do
      unknown = Class.new do
        def deliver(_message) = raise(Admissions::Delivery::OutcomeUnknown, 'timed out')
      end.new
      email = Admissions::EmailSender.request_automatic!(applicant, 'confirmation')
      expect do
        Admissions::EmailSender.new(Admissions::Actor.staff(lead), delivery: unknown).send_held!(email)
      end.to raise_error(Admissions::Delivery::OutcomeUnknown)

      get path
      expect(page.css('.admissions-sent-email')).to be_empty
      expect(page.at_css('.admissions-upcoming').text.squish)
        .to include('EOI confirmation outcome unknown: check the admissions@ Sent folder.')

      staff_sender(officer).confirm_sent!(email)
      get path
      expect(page.at_css('.admissions-sent-email').text.squish)
        .to include('Confirmed sent by Officer Person, who found it in the admissions@ Sent folder.',
                    'Subject: Welcome Test Person')
    end

    it 'shows a withdrawn applicant\'s emails as blanked, never as an error' do
      staff_sender(lead).send_now!(applicant, 'confirmation')
      staff_changes(lead).withdraw!(applicant)

      get path
      expect(response).to have_http_status(:ok)
      expect(page.at_css('.admissions-sent-email').text.squish)
        .to include('EOI confirmation', 'Text blanked when the applicant withdrew.')
      expect(response.body).not_to include('Welcome Test Person')
    end

    it 'says so when nothing has been sent' do
      get path
      expect(text).to include('No email has been sent to this applicant.',
                              "Replies to admissions@ aren't shown here yet.")
    end
  end

  describe 'upcoming emails' do
    before do
      sign_in officer
      email_template(round, 'confirmation')
    end

    it 'lists what is held for approval, linking to it in the queue' do
      email = Admissions::EmailSender.request_automatic!(applicant, 'confirmation')

      get path
      upcoming = page.at_css('.admissions-upcoming')
      expect(upcoming.text.squish).to include('EOI confirmation held for approval since', 'drafted by the system')
      expect(upcoming.at_css("a[href='/admissions/staff/emails#email-#{email.id}']").text)
        .to eq 'Open it in the approval queue'
      expect(text).to include("Weekly reminders aren't sent yet, so none are listed here.")
    end

    it 'says nothing is waiting, and why nothing automatic will be drafted' do
      get path
      expect(text).to include('Nothing is waiting to be sent.')
      expect(text).not_to include('is paused, so none is drafted')

      staff_changes.pause_emails!(applicant)
      get path
      expect(text).to include('Automatic email to this applicant is paused, so none is drafted.')

      staff_changes.flag_complicated!(applicant, note: 'x', check_back_on: Date.current + 1)
      get path
      expect(text).to include('flagged "it\'s complicated", so no automatic email is drafted for them.')
    end
  end

  describe 'history' do
    before { sign_in officer }

    it 'lists every event newest first, attributed, with each reason in plain words' do
      email_template(round, 'confirmation', subject: 'Hi {{name}}')
      round.update!(email_modes: { 'holding' => 'off' })
      staff_changes(lead).add_note!(applicant, body: 'Met at the summer party')
      applicant_changes(applicant).record_repeat_eoi!(applicant, phone: '07700 900999')
      Admissions::EmailSender.request_automatic!(applicant, 'holding')
      Admissions::EmailSender.request_automatic!(applicant, 'task')
      staff_changes.update_details!(applicant, name: nil)
      Admissions::EmailSender.request_automatic!(applicant, 'confirmation')
      staff_changes(officer).pause_emails!(applicant)
      Admissions::EmailSender.request_automatic!(applicant, 'confirmation')

      get path
      entries = page.css('.admissions-history li').map { |li| li.text.squish }
      expect(entries.size).to eq applicant.events.count
      expect(entries.first).to include('the system', 'EOI confirmation skipped: automatic email to this ' \
                                                     'applicant is paused')
      expect(entries.second).to include('Officer Person', 'Automatic email paused')
      expect(entries.third).to include('EOI confirmation not drafted: its template uses a placeholder ' \
                                       "this applicant can't fill")
      expect(entries).to include(a_string_including('Task not drafted: the round has no template for it'))
      expect(entries).to include(a_string_including("Holding email (EOI out of round) skipped: this email's " \
                                                    "mode is Off in the round's settings"))
      expect(entries).to include(a_string_including('the applicant',
                                                    'Sent the EOI form again with the same address. Nothing ' \
                                                    'changed and no email was sent; they gave a different ' \
                                                    'phone number.', 'Phone number given: 07700 900999'))
      expect(entries).to include(a_string_including('Lead Person', 'Note', 'Met at the summer party'))
      expect(entries.last).to include('Card created at EOI')
    end

    it 'names the EOI form and its privacy notice, and a card created by hand with its first-interest date' do
      notice = Admissions::FormText.create!(key: 'privacy_notice', body: 'We keep your details.',
                                            created_by_user: lead)
      from_form = applicant_changes.create!(
        round: round, email: 'form@example.com',
        details: { 'via' => 'eoi_form', 'privacy_notice_version' => notice.id }
      )
      by_hand = staff_changes.create!(round: round, email: 'hand@example.com',
                                      details: { 'via' => 'by_hand', 'first_interest_on' => '2026-03-04' })

      get "/admissions/staff/applicants/#{from_form.id}"
      expect(text).to include("Expressed interest through the EOI form (privacy notice version #{notice.id})")
      get "/admissions/staff/applicants/#{by_hand.id}"
      expect(text).to include('Card created by hand at EOI, first expressed interest March 04, 2026',
                              'First expressed interest March 04, 2026 (entered by hand)')
    end
  end

  describe 'actions, each through ApplicantChanges and attributed' do
    before { sign_in officer }

    it 'adds a note, which appears in the history' do
      post path('/note'), params: { body: "  A long call.\nPromising.  " }
      expect(response).to redirect_to(path)
      follow_redirect!
      expect(text).to include('Note added.')
      expect(last_event).to have_attributes(kind: 'note_added', actor_user: officer, body: "A long call.\nPromising.")
      expect(page.at_css('.admissions-history li').text).to include('Officer Person', "A long call.\nPromising.")

      post path('/note'), params: { body: '  ' }
      follow_redirect!
      expect(text).to include('Nothing done: a note needs text.')
      expect(kinds.count('note_added')).to eq 1
    end

    it 'flags "it\'s complicated" with a note and a check-back date, and clears it' do
      post path('/flag_complicated'), params: { note: 'Waiting on a visa', check_back_on: '' }
      follow_redirect!
      expect(text).to include("Nothing done: \"it's complicated\" needs a check-back date, today or later.")
      expect(applicant.reload.complicated).to be false

      post path('/flag_complicated'), params: { note: 'Waiting on a visa', check_back_on: (Date.current + 7).iso8601 }
      follow_redirect!
      expect(text).to include("Flagged \"it's complicated\". No automatic email goes to Test Person")
      expect(applicant.reload).to have_attributes(complicated: true, complicated_note: 'Waiting on a visa',
                                                  complicated_check_back_on: Date.current + 7)
      expect(last_event).to have_attributes(kind: 'flagged_complicated', actor_user: officer)

      post path('/clear_complicated')
      follow_redirect!
      expect(text).to include("\"It's complicated\" cleared.")
      expect(applicant.reload.complicated).to be false
      expect(last_event).to have_attributes(kind: 'cleared_complicated', actor_user: officer)
    end

    it 'holds until a date with a reason, and returns from hold' do
      post path('/hold'), params: { hold_until: Date.current.iso8601, reason: 'Exams' }
      follow_redirect!
      expect(text).to include('Nothing done: a hold needs a return date after today.')

      post path('/hold'), params: { hold_until: (Date.current + 10).iso8601, reason: 'Exams' }
      follow_redirect!
      expect(text).to include('On hold until')
      expect(applicant.reload).to have_attributes(stage: 'on_hold', held_from_stage: 'eoi', hold_reason: 'Exams')
      expect(last_event).to have_attributes(kind: 'held', actor_user: officer, body: 'Exams')

      post path('/return_from_hold')
      follow_redirect!
      expect(text).to include('Returned from hold to EOI.')
      expect(applicant.reload.stage).to eq 'eoi'
      expect(last_event).to have_attributes(kind: 'returned_from_hold', actor_user: officer)
    end

    it 'moves to any stage after a confirmation that says no email is sent' do
      get path('/move?to=interview_offered')
      expect(response).to have_http_status(:ok)
      expect(text).to include('Move Test Person to Interview offered', 'From EOI to Interview offered.',
                              'This move sends no email.')

      post path('/move'), params: { to: 'interview_offered', note: 'Known to us: fast-track' }
      follow_redirect!
      expect(text).to include('Moved to Interview offered. No email was sent.')
      expect(applicant.reload.stage).to eq 'interview_offered'
      expect(last_event).to have_attributes(kind: 'moved', actor_user: officer, from_stage: 'eoi',
                                            to_stage: 'interview_offered', body: 'Known to us: fast-track')
      expect(applicant.emails).to be_empty
      expect(recorded_emails).to be_empty

      get path('/move?to=interview_offered')
      expect(response).to redirect_to(path)
      get path('/move?to=withdrawn')
      expect(response).to redirect_to(path)
      post path('/move'), params: { to: 'withdrawn' }
      follow_redirect!
      expect(text).to include('Nothing done: cannot move to withdrawn')
    end

    it 'says a move also ends a hold' do
      staff_changes.hold!(applicant, until_date: Date.current + 3, reason: 'x')
      get path('/move?to=applied')
      expect(text).to include('This also ends their hold.')
    end

    it 'defers, and reopens' do
      post path('/defer'), params: { note: 'Too busy this year' }
      follow_redirect!
      expect(text).to include('Deferred: kept for next round.')
      expect(applicant.reload.stage).to eq 'deferred'
      expect(last_event).to have_attributes(kind: 'exited', to_stage: 'deferred', actor_user: officer,
                                            body: 'Too busy this year')

      post path('/reopen')
      follow_redirect!
      expect(text).to include('Reopened at EOI.')
      expect(last_event).to have_attributes(kind: 'reopened', actor_user: officer)
    end

    it 'pauses and resumes automatic email from the card' do
      get path
      expect(page.at_css('form[action$="/pause_emails"]')).to be_present

      post path('/pause_emails')
      follow_redirect!
      expect(text).to include('Automatic email to Test Person is paused.')
      expect(page.at_css('form[action$="/resume_emails"]')).to be_present
      expect(last_event).to have_attributes(kind: 'emails_paused', actor_user: officer)
    end
  end

  describe 'withdrawal' do
    before do
      email_template(round, 'confirmation', subject: 'Welcome {{name}}')
      staff_sender(lead).send_now!(applicant, 'confirmation')
      Admissions::EmailSender.request_automatic!(applicant, 'confirmation')
      staff_changes(lead).add_note!(applicant, body: 'Private note')
    end

    it 'asks a lead for a clear confirmation, saying exactly what is erased and that it cannot be undone' do
      sign_in lead
      get path('/withdraw')
      expect(response).to have_http_status(:ok)
      expect(text).to include('Withdraw Test Person: remove their details',
                              'If they\'re dropping out, defer them instead',
                              'Their email address, phone number and name on this record, in Fellowship 2027.',
                              '2 emails, sent or not, with each one\'s subject, body and address.',
                              '1 email waiting for approval will be discarded',
                              'An anonymous record', 'they have no records in other rounds',
                              "This can't be undone.")

      post path('/withdraw')
      follow_redirect!
      expect(text).to include('Nothing done: tick the box to confirm the erasure first.')
      expect(applicant.reload.stage).to eq 'eoi'

      post path('/withdraw'), params: { confirm: '1' }
      expect(response).to redirect_to(path)
      follow_redirect!
      expect(text).to include('Withdrawn. Their details on this record are erased.')
      expect(applicant.reload).to have_attributes(stage: 'withdrawn', email: nil, phone: nil, name: nil)
      expect(applicant.events.find_by(kind: 'exited')).to have_attributes(to_stage: 'withdrawn', actor_user: lead)
      expect(response.body).not_to include('Private note', 'Welcome Test Person', 'test.person@example.com')
      expect(text).to include("Withdrawn applicant ##{applicant.id}", 'Text removed when the applicant withdrew.')

      get path('/withdraw')
      expect(response).to redirect_to(path)
    end

    it 'lists the same person in other rounds, to withdraw each' do
      later_round = Fabricate(:admissions_round, opens_on: Date.new(2027, 9, 1), invites_on: Date.new(2028, 2, 1),
                                                 closes_on: Date.new(2028, 6, 30), name: 'Fellowship 2028')
      later = staff_changes.create!(round: later_round, email: 'test.person@example.com',
                                    previous_applicant: applicant)
      sign_in lead
      get path('/withdraw')
      expect(page.at_css("a[href='/admissions/staff/applicants/#{later.id}']").text).to eq 'Fellowship 2028 (EOI)'
    end

    it 'is a lead\'s act: an officer can do neither step' do
      sign_in officer
      get path
      expect(text).to include('Only an admissions lead can withdraw an applicant')
      expect(page.at_css("a[href='#{path('/withdraw')}']")).to be_nil

      get path('/withdraw')
      expect(response).to redirect_to('/admissions/staff')
      post path('/withdraw'), params: { confirm: '1' }
      follow_redirect!
      expect(text).to include('Only an admissions lead can do that.')
      expect(applicant.reload.stage).to eq 'eoi'
    end
  end

  describe 'cards created by hand' do
    before { sign_in officer }

    def card_params(**overrides)
      { round_id: round.id, email: 'new.person@example.com', phone: '', name: 'New Person', stage: 'eoi',
        first_interest_on: '' }.merge(overrides)
    end

    def new_card = Admissions::Applicant.find_by(email: 'new.person@example.com')

    # Relative to today, which another spec may have moved.
    let(:first_interest) { Date.current - 200 }

    before do
      email_template(round, 'confirmation', subject: 'Welcome {{name}}', body: 'Thanks for your interest, {{name}}.')
      email_template(round, 'holding', subject: 'What happens next', body: 'Applications open in February.')
    end

    it 'offers the form, defaulting to the round the EOI form fills' do
      get '/admissions/staff/applicants/new'
      expect(response).to have_http_status(:ok)
      expect(page.at_css('#card_round_id option[selected]').text).to eq 'Fellowship 2027'
      expect(page.at_css('#card_stage option[selected]').text).to eq 'EOI'
      expect(page.at_css('input[name="card[send_emails][]"]')).to be_nil
    end

    it 'at eoi, previews each email unticked, then creates the card sending nothing unless ticked' do
      post '/admissions/staff/applicants', params: { card: card_params, continue: '1' }
      expect(response).to have_http_status(:ok)
      expect(Admissions::Applicant.count).to eq 1
      boxes = page.css('input[type=checkbox][name="card[send_emails][]"]')
      expect(boxes.map { |b| b['value'] }).to eq %w[confirmation holding]
      expect(boxes.map { |b| b['checked'] }).to all(be_nil)
      expect(text).to include('Send the EOI confirmation', 'Subject: Welcome New Person',
                              'Thanks for your interest, New Person.', 'Send the Holding email (EOI out of round)',
                              'Applications open in February.')

      digest = page.at_css('input[name=preview_digest]')['value']
      post '/admissions/staff/applicants', params: { card: card_params, create: '1', preview_digest: digest }
      expect(response).to redirect_to("/admissions/staff/applicants/#{new_card.id}")
      follow_redirect!
      expect(text).to include('Card created for New Person.')
      expect(new_card).to have_attributes(stage: 'eoi', name: 'New Person', phone: nil)
      expect(new_card.created_event).to have_attributes(actor_type: 'staff', actor_user: officer,
                                                        details: { 'via' => 'by_hand' })
      expect(new_card.first_interest_on).to eq Date.current
      expect(new_card.emails).to be_empty
      expect(recorded_emails).to be_empty
    end

    it 'keeps a first-interest date, and sends the ticked emails through send_now!, attributed' do
      post '/admissions/staff/applicants',
           params: { card: card_params(first_interest_on: first_interest.iso8601), continue: '1' }
      digest = page.at_css('input[name=preview_digest]')['value']
      post '/admissions/staff/applicants',
           params: { card: card_params(first_interest_on: first_interest.iso8601, send_emails: ['confirmation']),
                     create: '1', preview_digest: digest }
      follow_redirect!
      expect(text).to include('Card created for New Person. EOI confirmation sent.')

      expect(new_card.created_event.details).to eq('via' => 'by_hand', 'first_interest_on' => first_interest.iso8601)
      expect(new_card.first_interest_on).to eq first_interest
      expect(new_card.stage_entered_at.to_date).to eq Date.current
      expect(new_card.emails.map { |e| [e.email_type, e.status, e.sent_by_user] })
        .to eq [['confirmation', 'sent', officer]]
      expect(recorded_emails.map(&:subject)).to eq ['Welcome New Person']
      expect(Admissions::StateRebuilder.consistent?(new_card)).to be true
    end

    it 'refuses to send a text other than the one previewed' do
      post '/admissions/staff/applicants', params: { card: card_params, continue: '1' }
      digest = page.at_css('input[name=preview_digest]')['value']
      post '/admissions/staff/applicants',
           params: { card: card_params(name: 'Changed Name', send_emails: ['confirmation']),
                     create: '1', preview_digest: digest }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(text).to include('The emails changed since you saw them.', 'Welcome Changed Name')
      expect(Admissions::Applicant.count).to eq 1
      expect(recorded_emails).to be_empty
    end

    it 'shows an email that cannot be drafted, with no box to tick' do
      round.email_templates.find_by(email_type: 'holding').destroy!
      post '/admissions/staff/applicants', params: { card: card_params(name: ''), continue: '1' }
      expect(text).to include('EOI confirmation can\'t be sent: The EOI confirmation template uses {{name}}, ' \
                              'but this applicant has none.',
                              'Holding email (EOI out of round) can\'t be sent: There is no Holding email ' \
                              '(EOI out of round) template for Fellowship 2027 yet.')
      expect(page.css('input[name="card[send_emails][]"]')).to be_empty
    end

    it 'at a later stage, creates the card at once and offers no emails' do
      post '/admissions/staff/applicants', params: { card: card_params(stage: 'interview_offered'), continue: '1' }
      expect(response).to redirect_to("/admissions/staff/applicants/#{new_card.id}")
      expect(new_card.stage).to eq 'interview_offered'
      expect(new_card.first_interest_on).to eq Date.current
      expect(new_card.emails).to be_empty

      post '/admissions/staff/applicants',
           params: { card: card_params(email: 'other@example.com', stage: 'applied', first_interest_on: first_interest.iso8601,
                                       send_emails: ['confirmation']), create: '1' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(text).to include("A card at this stage can't send EOI confirmation.")
      expect(Admissions::Applicant.find_by(email: 'other@example.com')).to be_nil

      post '/admissions/staff/applicants',
           params: { card: card_params(email: 'other@example.com', stage: 'applied',
                                       first_interest_on: first_interest.iso8601), continue: '1' }
      other = Admissions::Applicant.find_by(email: 'other@example.com')
      expect(other.first_interest_on).to eq first_interest
    end

    it 'refuses a duplicate address in the same round, in any case, linking to the existing card' do
      post '/admissions/staff/applicants',
           params: { card: card_params(email: 'Test.Person@Example.com'), continue: '1' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(text).to include('Fellowship 2027 already has a card for this address.',
                              'Open the existing card for Test Person')
      expect(page.at_css("a[href='/admissions/staff/applicants/#{applicant.id}']")).to be_present
      expect(Admissions::Applicant.count).to eq 1
    end

    it 'links the card to the same person in an earlier round' do
      later_round = Fabricate(:admissions_round, name: 'Later round', opens_on: Date.new(2027, 9, 1),
                                                 invites_on: Date.new(2028, 2, 1), closes_on: Date.new(2028, 6, 30))
      post '/admissions/staff/applicants',
           params: { card: card_params(round_id: later_round.id, email: 'test.person@example.com', stage: 'applied'),
                     continue: '1' }
      created = later_round.applicants.first
      expect(created.previous_applicant).to eq applicant
    end

    it 'refuses a bad address, a date in the future, and a missing round' do
      post '/admissions/staff/applicants',
           params: { card: card_params(email: 'nope', first_interest_on: (Date.current + 1).iso8601, round_id: 0),
                     continue: '1' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(text).to include("That doesn't look like an email address.", "That's in the future.", 'Choose a round.')
      expect(Admissions::Applicant.count).to eq 1
    end
  end
end
