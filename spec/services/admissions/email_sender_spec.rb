require 'rails_helper'

RSpec.describe Admissions::EmailSender do
  let(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027') }
  let(:lead) { admissions_staff }
  let(:applicant) { create_applicant(round: round, stage: 'eoi', name: 'Test Person', email: 'test.person@example.com') }
  let(:expected_subject) { 'Test subject for Test Person' }
  let(:expected_body) { "Test body, Test Person, for Fellowship 2027.\nSecond line." }
  let(:expected_text) { "Subject: #{expected_subject}\n\n#{expected_body}" }

  before { email_template(round, 'confirmation') }

  def set_mode(type, mode)
    round.update!(email_modes: round.email_modes.merge(type => mode))
  end

  def events(kind) = applicant.events.where(kind: kind)

  describe '.request_automatic!' do
    it 'holds the email by default, since every type starts on ask me first' do
      email = described_class.request_automatic!(applicant, 'confirmation')

      expect(email).to be_held
      expect(email).to have_attributes(subject: expected_subject, body: expected_body, email_type: 'confirmation',
                                       drafted_by_type: 'system', drafted_by_user: nil, sent_at: nil)
      expect(email.drafted_by).to eq Admissions::Actor.system
      expect(recorded_emails).to be_empty

      drafted = events('email_drafted').sole
      expect(drafted).to have_attributes(actor_type: 'system', body: expected_text)
      expect(drafted.details).to eq('email_id' => email.id, 'email_type' => 'confirmation', 'mode' => 'ask_me_first')
      expect(drafted.email_text).to eq [expected_subject, expected_body]
    end

    it 'drafts and sends on automatic' do
      set_mode('confirmation', 'automatic')
      email = described_class.request_automatic!(applicant, 'confirmation')

      expect(email).to be_sent
      expect(email).to have_attributes(sent_by_type: 'system', to_address: 'test.person@example.com',
                                       delivery: 'recording')
      expect(email.sent_at).to be_present
      expect(recorded_emails.map(&:to_h)).to eq [{ to: 'test.person@example.com', subject: expected_subject,
                                                   body: expected_body, email_id: email.id }]
      expect(applicant.events.map(&:kind)).to eq %w[created email_drafted email_sent]

      sent = events('email_sent').sole
      expect(sent).to have_attributes(actor_type: 'system', body: expected_text)
      expect(sent.details).to include('email_id' => email.id, 'delivery' => 'recording',
                                      'delivery_message_id' => email.delivery_message_id)
    end

    it 'drafts nothing on off, and records the skip' do
      set_mode('confirmation', 'off')
      expect(described_class.request_automatic!(applicant, 'confirmation')).to be_nil

      expect(applicant.emails).to be_empty
      skipped = events('email_skipped').sole
      expect(skipped.details).to eq('email_type' => 'confirmation', 'reason' => 'off', 'mode' => 'off')
      expect(skipped.actor_type).to eq 'system'
    end

    describe 'drafts nothing automatic, whatever the mode, for an applicant who is' do
      before { set_mode('confirmation', 'automatic') }

      it "flagged \"it's complicated\"" do
        staff_changes.flag_complicated!(applicant, note: 'Handled by hand', check_back_on: Date.current + 3)
        expect(described_class.request_automatic!(applicant, 'confirmation')).to be_nil

        expect(applicant.emails).to be_empty
        expect(events('email_skipped').sole.details).to include('reason' => 'complicated', 'mode' => 'automatic')
      end

      it 'withdrawn' do
        staff_changes.withdraw!(applicant)
        expect(described_class.request_automatic!(applicant, 'confirmation')).to be_nil

        expect(applicant.emails).to be_empty
        expect(events('email_skipped').sole.details).to include('reason' => 'withdrawn')
      end

      it 'paused' do
        staff_changes.pause_emails!(applicant)
        expect(described_class.request_automatic!(applicant, 'confirmation')).to be_nil

        expect(applicant.emails).to be_empty
        expect(events('email_skipped').sole.details).to include('reason' => 'paused')
        expect(recorded_emails).to be_empty
      end

      it 'paused, and drafts again once resumed' do
        staff_changes.pause_emails!(applicant)
        staff_changes.resume_emails!(applicant)
        expect(described_class.request_automatic!(applicant, 'confirmation')).to be_sent
      end
    end

    it 'gives the most fundamental reason when several apply' do
      staff_changes.pause_emails!(applicant)
      staff_changes.flag_complicated!(applicant, note: 'n', check_back_on: Date.current)
      described_class.request_automatic!(applicant, 'confirmation')
      expect(events('email_skipped').sole.details['reason']).to eq 'complicated'
    end

    it 'reads the applicant afresh, not a stale copy' do
      stale = Admissions::Applicant.find(applicant.id)
      staff_changes.pause_emails!(applicant)
      expect(described_class.request_automatic!(stale, 'confirmation')).to be_nil
    end

    it 'refuses a type with no template, saying so, and drafts nothing' do
      expect { described_class.request_automatic!(applicant, 'holding') }
        .to raise_error(described_class::MissingTemplate,
                        'There is no Holding email (EOI out of round) template for Fellowship 2027: ' \
                        'add one under Admissions, Email templates, before this email can be drafted')
      expect(applicant.emails).to be_empty
      expect(applicant.events.map(&:kind)).to eq %w[created]
    end

    it 'needs no template for a type that is off' do
      set_mode('holding', 'off')
      expect(described_class.request_automatic!(applicant, 'holding')).to be_nil
    end

    it 'refuses a placeholder it cannot fill, drafting nothing' do
      email_template(round, 'holding', body: 'Your link: {{portal_link}}')
      expect { described_class.request_automatic!(applicant, 'holding') }
        .to raise_error(Admissions::EmailTemplate::RenderError, /no portal link until the applicant portal is built/)
      expect(applicant.emails).to be_empty
    end

    it 'fills placeholders a later phase supplies' do
      email_template(round, 'holding', body: 'Your link: {{portal_link}}')
      email = described_class.request_automatic!(applicant, 'holding', values: { portal_link: 'https://example.com/p/1' })
      expect(email.body).to eq 'Your link: https://example.com/p/1'
    end

    it 'is asked for by the system only' do
      expect { staff_sender(lead).request_automatic!(applicant, 'confirmation') }
        .to raise_error(Admissions::ApplicantChanges::NotPermitted)
      expect { Admissions::EmailSender.new(Admissions::Actor.applicant(applicant)).request_automatic!(applicant, 'confirmation') }
        .to raise_error(Admissions::ApplicantChanges::NotPermitted)
    end

    it 'refuses an unknown type' do
      expect { described_class.request_automatic!(applicant, 'love_letter') }.to raise_error(ArgumentError)
    end

    describe 'when an automatic send fails' do
      let(:failing) do
        Class.new do
          def deliver(_message) = raise(Admissions::Delivery::NotConfigured, 'Gmail delivery is not configured: set X')
        end.new
      end

      before do
        set_mode('confirmation', 'automatic')
        Admissions::Delivery.adapter = failing
      end

      after { Admissions::Delivery.adapter = nil }

      it 'keeps the email held for staff, and logs why' do
        email = described_class.request_automatic!(applicant, 'confirmation')

        expect(email).to be_held
        expect(applicant.events.map(&:kind)).to eq %w[created email_drafted email_send_failed]
        expect(events('email_send_failed').sole.details)
          .to include('email_id' => email.id, 'error' => 'Gmail delivery is not configured: set X')
      end
    end
  end

  describe '#send_now! (a staff button: the click is the approval)' do
    it 'drafts and sends at once, attributed to the staff member' do
      email = staff_sender(lead).send_now!(applicant, 'confirmation')

      expect(email).to be_sent
      expect(email.sent_by).to eq Admissions::Actor.staff(lead)
      expect(email.drafted_by).to eq Admissions::Actor.staff(lead)
      expect(recorded_emails.size).to eq 1
      expect(applicant.events.where(kind: %w[email_drafted email_sent]).map { |e| [e.kind, e.actor_user, e.body] })
        .to eq [['email_drafted', lead, expected_text], ['email_sent', lead, expected_text]]
      expect(events('email_drafted').sole.details).not_to have_key('mode')
    end

    it 'sends whatever the mode, and while paused or complicated, which stop only automatic email' do
      set_mode('confirmation', 'off')
      staff_changes.pause_emails!(applicant)
      staff_changes.flag_complicated!(applicant, note: 'n', check_back_on: Date.current)
      expect(staff_sender(lead).send_now!(applicant, 'confirmation')).to be_sent
    end

    it 'never sends to a withdrawn applicant' do
      staff_changes.withdraw!(applicant)
      expect { staff_sender(lead).send_now!(applicant, 'confirmation') }
        .to raise_error(described_class::NotSendable)
      expect(applicant.emails).to be_empty
    end

    it 'refuses a type with no template' do
      expect { staff_sender(lead).send_now!(applicant, 'task') }
        .to raise_error(described_class::MissingTemplate, /There is no Task template for Fellowship 2027/)
    end

    it 'is staff only' do
      expect { system_sender.send_now!(applicant, 'confirmation') }
        .to raise_error(Admissions::ApplicantChanges::NotPermitted)
    end

    it 'refuses a user without an admissions role' do
      expect { Admissions::EmailSender.new(Admissions::Actor.staff(Fabricate(:user, role: 'admin'))) }
        .to raise_error(Admissions::ApplicantChanges::NotPermitted)
    end

    it 'leaves the email held when delivery fails, and says why' do
      Admissions::Delivery.adapter = Class.new { def deliver(_) = raise(Admissions::Delivery::Error, 'Gmail refused') }.new
      expect { staff_sender(lead).send_now!(applicant, 'confirmation') }
        .to raise_error(Admissions::Delivery::Error, 'Gmail refused')

      email = applicant.emails.sole
      expect(email).to be_held
      expect(events('email_send_failed').sole).to have_attributes(actor_user: lead)
    ensure
      Admissions::Delivery.adapter = nil
    end
  end

  describe 'the approval queue' do
    let(:officer) { admissions_staff(role: 'officer') }
    let!(:email) { described_class.request_automatic!(applicant, 'confirmation') }

    describe '#edit!' do
      it 'changes the held text and logs the new text, attributed' do
        staff_sender(officer).edit!(email, subject: '  Edited subject  ', body: "Edited\r\nbody")

        expect(email).to have_attributes(subject: 'Edited subject', body: "Edited\nbody", status: 'held')
        expect(email.edited_by).to eq Admissions::Actor.staff(officer)
        expect(email.edited_at).to be_present
        edited = events('email_edited').sole
        expect(edited).to have_attributes(actor_user: officer, body: "Subject: Edited subject\n\nEdited\nbody")
        expect(edited.details).to eq('email_id' => email.id, 'email_type' => 'confirmation')
      end

      it 'logs nothing when nothing changed' do
        staff_sender(officer).edit!(email, subject: expected_subject, body: expected_body)
        expect(events('email_edited')).to be_empty
        expect(email.edited_at).to be_nil
      end

      it 'refuses an empty subject or body, or a subject over two lines' do
        expect { staff_sender.edit!(email, subject: '', body: 'b') }.to raise_error(ActiveRecord::RecordInvalid)
        expect { staff_sender.edit!(email, subject: 's', body: ' ') }.to raise_error(ActiveRecord::RecordInvalid)
        expect { staff_sender.edit!(email, subject: "one\ntwo", body: 'b') }.to raise_error(ActiveRecord::RecordInvalid)
        expect(email.reload.subject).to eq expected_subject
        expect(events('email_edited')).to be_empty
      end

      it 'is staff only' do
        expect { system_sender.edit!(email, subject: 's', body: 'b') }
          .to raise_error(Admissions::ApplicantChanges::NotPermitted)
      end
    end

    describe '#send_held!' do
      it 'sends the text as edited, attributed to whoever approved it' do
        staff_sender(officer).edit!(email, subject: 'Edited subject', body: 'Edited body')
        staff_sender(lead).send_held!(email)

        expect(email).to be_sent
        expect(email.sent_by).to eq Admissions::Actor.staff(lead)
        expect(recorded_emails.map { |m| [m.subject, m.body] }).to eq [['Edited subject', 'Edited body']]
        expect(events('email_sent').sole).to have_attributes(actor_user: lead,
                                                             body: "Subject: Edited subject\n\nEdited body")
      end

      it 'goes to the address the applicant has when it is sent' do
        staff_changes.update_details!(applicant, email: 'corrected@example.com')
        staff_sender.send_held!(email)
        expect(recorded_emails.sole.to).to eq 'corrected@example.com'
        expect(email.to_address).to eq 'corrected@example.com'
      end

      it 'sends once, however many staff press send' do
        other_copy = Admissions::Email.find(email.id)
        staff_sender(lead).send_held!(email)
        expect { staff_sender(officer).send_held!(other_copy) }
          .to raise_error(described_class::NotSendable, 'this email has already been sent')
        expect(recorded_emails.size).to eq 1
        expect(events('email_sent').count).to eq 1
      end

      it 'sends while the applicant is paused: approving is a staff decision' do
        staff_changes.pause_emails!(applicant)
        expect(staff_sender.send_held!(email)).to be_sent
      end
    end

    describe '#discard!' do
      it 'discards with the text, attributed' do
        staff_sender(officer).discard!(email)

        expect(email).to be_discarded
        expect(email.discarded_by).to eq Admissions::Actor.staff(officer)
        expect(events('email_discarded').sole).to have_attributes(actor_user: officer, body: expected_text)
        expect(recorded_emails).to be_empty
      end

      it 'cannot then be sent or edited' do
        staff_sender.discard!(email)
        expect { staff_sender.send_held!(email) }.to raise_error(described_class::NotSendable)
        expect { staff_sender.edit!(email, subject: 's', body: 'b') }.to raise_error(described_class::NotSendable)
        expect { staff_sender.discard!(email) }.to raise_error(described_class::NotSendable)
      end
    end

    describe 'withdrawal' do
      it 'discards held emails and blanks the text of every email and its events' do
        set_mode('confirmation', 'automatic')
        sent = described_class.request_automatic!(applicant, 'confirmation')
        staff_changes.withdraw!(applicant)

        expect(email.reload).to be_discarded
        expect(email.discarded_by_type).to eq 'staff'
        [email, sent.reload].each do |e|
          expect(e).to have_attributes(subject: nil, body: nil, to_address: nil)
          expect(e.redacted_at).to be_present
        end
        expect(applicant.events.where(kind: Admissions::ApplicantEvent::EMAIL_KINDS).pluck(:body).compact).to be_empty
        expect(events('email_discarded').sole.details).to include('email_id' => email.id, 'reason' => 'withdrawn')
        expect(described_class.request_automatic!(applicant, 'confirmation')).to be_nil
      end
    end
  end

  describe 'the last contact, for reminders' do
    it 'is the latest email sent, or entering the stage if later' do
      set_mode('confirmation', 'automatic')
      entered = applicant.stage_entered_at
      expect(applicant.last_contacted_at).to eq entered

      Timecop.travel(2.days.from_now) do
        email = described_class.request_automatic!(applicant, 'confirmation')
        expect(applicant.reload.last_contacted_at).to eq email.sent_at
      end
    end
  end

  describe 'the database guards on the outbox' do
    let!(:email) { described_class.request_automatic!(applicant, 'confirmation') }

    it 'refuses writes from outside the email-sender' do
      expect_refused(ActiveRecord::RecordInvalid) { email.update!(subject: 'Sneaky') }
      expect_refused(ActiveRecord::StatementInvalid, /written only through Admissions::EmailSender/) do
        Admissions::Email.where(id: email.id).update_all(subject: 'Sneaky')
      end
      expect_refused(ActiveRecord::StatementInvalid, /written only through Admissions::EmailSender/) do
        Admissions::Email.insert_all([email.attributes.except('id')])
      end
    end

    it 'never deletes an email' do
      expect_refused(ActiveRecord::ReadOnlyRecord) { email.destroy }
      expect_refused(ActiveRecord::StatementInvalid, /never deleted/) { Admissions::Email.where(id: email.id).delete_all }
      expect_refused(ActiveRecord::StatementInvalid, /never deleted/) do
        ActiveRecord::Base.connection.execute('TRUNCATE admissions_emails CASCADE')
      end
    end

    it 'never changes a sent email, even with the service permission' do
      staff_sender.send_held!(email)
      expect_refused(ActiveRecord::StatementInvalid, /does not change/) do
        with_service_write { Admissions::Email.where(id: email.id).update_all(body: 'Rewritten history') }
      end
      expect_refused(ActiveRecord::StatementInvalid, /does not change/) do
        with_service_write { Admissions::Email.where(id: email.id).update_all(status: 'held') }
      end
    end

    it 'lets the services write inside a query-cached web request' do
      ActiveRecord::Base.cache do
        staff_changes.pause_emails!(applicant)
        staff_changes.resume_emails!(applicant)
        staff_sender.edit!(email, subject: 'One', body: 'b')
        staff_sender.edit!(email, subject: 'Two', body: 'b')
        staff_sender.send_held!(email)
        expect { email.update!(subject: 'Sneaky') }.to raise_error(ActiveRecord::RecordInvalid)
      end
      expect(email.reload).to have_attributes(status: 'sent', subject: 'Two')
    end

    it "refuses changes to the pause switch from outside ApplicantChanges" do
      expect_refused(ActiveRecord::StatementInvalid, /only through Admissions::ApplicantChanges/) do
        Admissions::Applicant.where(id: applicant.id).update_all(emails_paused: true)
      end
    end
  end
end
