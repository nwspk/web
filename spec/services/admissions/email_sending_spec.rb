require 'rails_helper'

# The three steps of a send (EmailSender: sending, the mail service, sent)
# and what happens when one of them goes wrong.
RSpec.describe Admissions::EmailSender, 'sending' do
  let(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027') }
  let(:lead) { admissions_staff }
  let(:applicant) { create_applicant(round: round, name: 'Test Person', email: 'test.person@example.com') }
  let(:expected_text) do
    "Subject: Test subject for Test Person\n\nTest body, Test Person, for Fellowship 2027.\nSecond line."
  end

  before { email_template(round, 'confirmation') }
  after { Admissions::Delivery.adapter = nil }

  def deliver_with(&block) = Admissions::Delivery.adapter = Class.new { define_method(:deliver, &block) }.new
  def events(kind) = applicant.events.where(kind: kind)
  def set_mode(type, mode) = round.update!(email_modes: round.email_modes.merge(type => mode))

  describe 'when the outcome is unknown' do
    let!(:email) { described_class.request_automatic!(applicant, 'confirmation') }

    before { deliver_with { |_| raise Admissions::Delivery::OutcomeUnknown, 'the connection to Gmail was lost' } }

    it 'stays sending, says so, and is not offered for sending again' do
      expect { staff_sender(lead).send_held!(email) }
        .to raise_error(Admissions::Delivery::OutcomeUnknown, 'the connection to Gmail was lost')

      expect(email).to be_sending
      expect(email).to be_outcome_unknown
      expect(email.sent_by).to eq Admissions::Actor.staff(lead)
      expect(events('email_outcome_unknown').sole.details)
        .to include('email_id' => email.id, 'error' => 'Admissions::Delivery::OutcomeUnknown: the connection to Gmail was lost')
      expect { staff_sender(lead).send_held!(email) }
        .to raise_error(described_class::NotSendable, 'this email is being sent')
      expect { staff_sender(lead).edit!(email, subject: 's', body: 'b') }.to raise_error(described_class::NotSendable)
    end

    it 'never raises on the automatic path' do
      set_mode('confirmation', 'automatic')
      other = described_class.request_automatic!(create_applicant(round: round), 'confirmation')
      expect(other).to be_outcome_unknown
    end

    it 'is resolved as sent by staff who found it in the Sent folder, attributed' do
      staff_sender(lead).send_held!(email) rescue Admissions::Delivery::OutcomeUnknown # rubocop:disable Style/RescueModifier
      officer = admissions_staff(role: 'officer')
      staff_sender(officer).confirm_sent!(email)

      expect(email).to be_sent
      expect(email.delivery).to eq 'confirmed_by_staff'
      sent = events('email_sent').sole
      expect(sent).to have_attributes(actor_user: officer, body: expected_text)
      expect(sent.details).to include('confirmed_by_staff' => true)
    end

    it 'is resolved as not sent, going back to held and sendable again' do
      staff_sender(lead).send_held!(email) rescue Admissions::Delivery::OutcomeUnknown # rubocop:disable Style/RescueModifier
      staff_sender(lead).confirm_not_sent!(email)

      expect(email).to be_held
      expect(email).to have_attributes(sending_at: nil, outcome_unknown_at: nil, sent_by_type: nil, to_address: nil)
      expect(events('email_returned_to_held').sole).to have_attributes(actor_user: lead)

      Admissions::Delivery.adapter = nil
      expect(staff_sender(lead).send_held!(email)).to be_sent
    end

    it 'is discarded, not held, when resolved as not sent for an applicant who has since withdrawn' do
      staff_sender(lead).send_held!(email) rescue Admissions::Delivery::OutcomeUnknown # rubocop:disable Style/RescueModifier
      staff_changes.withdraw!(applicant)
      expect(email.reload).to be_sending
      expect(email.subject).to be_nil

      staff_sender(lead).confirm_not_sent!(email)
      expect(email).to be_discarded
    end
  end

  it 'leaves the outcome unknown when recording the send fails after the mail service took it' do
    email = described_class.request_automatic!(applicant, 'confirmation')
    allow(Admissions::ApplicantEvent).to receive(:create!).and_wrap_original do |original, **attrs|
      raise ActiveRecord::ConnectionNotEstablished, 'database gone' if attrs[:kind] == 'email_sent'

      original.call(**attrs)
    end

    expect { staff_sender(lead).send_held!(email) }
      .to raise_error(Admissions::Delivery::OutcomeUnknown, /the email went, but recording it failed/)
    expect(recorded_emails.size).to eq 1
    expect(email.reload).to be_outcome_unknown
    expect(events('email_outcome_unknown')).to exist
  end

  describe 'when the process dies after the email is marked sending' do
    let(:crash) { Class.new(Exception) } # rubocop:disable Lint/InheritException
    let!(:email) { described_class.request_automatic!(applicant, 'confirmation') }

    before do
      error = crash
      deliver_with { |_| raise error }
      expect { staff_sender(lead).send_held!(email) }.to raise_error(crash)
      email.reload
    end

    it 'stays sending, and is not resolvable while it might still be in progress' do
      expect(email).to be_sending
      expect(email).not_to be_outcome_unknown
      expect(events('email_outcome_unknown')).to be_empty
      expect { staff_sender(lead).confirm_sent!(email) }
        .to raise_error(described_class::NotSendable, 'this email is still being sent')
    end

    it 'becomes outcome unknown once stale, for staff to resolve' do
      Timecop.travel((Admissions::Email::STALE_AFTER + 1.minute).from_now) do
        expect(email).to be_outcome_unknown
        staff_sender(lead).confirm_not_sent!(email)
        expect(email).to be_held
      end
    end
  end

  describe 'inside the caller’s transaction' do
    before { set_mode('confirmation', 'automatic') }

    it 'sends only once that transaction commits' do
      email = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        email = described_class.request_automatic!(applicant, 'confirmation')
        expect(email).to be_sending
        expect(recorded_emails).to be_empty
      end
      expect(recorded_emails.size).to eq 1
      expect(email.reload).to be_sent
    end

    it 'sends nothing when that transaction rolls back' do
      ActiveRecord::Base.transaction(requires_new: true) do
        described_class.request_automatic!(applicant, 'confirmation')
        raise ActiveRecord::Rollback
      end
      expect(recorded_emails).to be_empty
      expect(applicant.emails).to be_empty
    end
  end

  # Real concurrency needs real commits, so this group runs outside the
  # test transaction and cleans up after itself.
  describe 'a send colliding with a withdrawal', :without_transaction do
    self.use_transactional_tests = false

    after do
      connection = ActiveRecord::Base.connection
      connection.execute('SET session_replication_role = replica')
      (connection.tables - %w[schema_migrations ar_internal_metadata]).each do |table|
        connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
      end
      connection.execute('SET session_replication_role = DEFAULT')
    end

    it 'neither deadlocks nor loses the send' do
      email = described_class.request_automatic!(applicant, 'confirmation')
      in_delivery = Queue.new
      may_finish = Queue.new
      deliver_with do |message|
        in_delivery << true
        may_finish.pop
        Admissions::Delivery::Receipt.new(delivery: 'recording', message_id: "slow-#{message.email_id}")
      end
      staff = lead
      withdrawer = admissions_staff

      sender = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { staff_sender(staff).send_held!(email) }
      end
      in_delivery.pop
      withdrawal = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          staff_changes(withdrawer).withdraw!(Admissions::Applicant.find(applicant.id))
        end
      end
      withdrawn_during_send = withdrawal.join(10)
      may_finish << true
      expect(withdrawn_during_send).to be_truthy # the withdrawal was not blocked by the send
      expect(withdrawal.join(10)).to be_truthy
      expect(sender.join(10)).to be_truthy
      expect(sender.value).to be_sent

      email.reload
      expect(email).to have_attributes(status: 'sent', delivery_message_id: "slow-#{email.id}", subject: nil)
      expect(applicant.reload).to be_withdrawn
      expect(events('email_sent').sole.body).to be_nil # withdrawal blanked the text meanwhile
    end
  end
end
