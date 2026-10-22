require 'rails_helper'

RSpec.describe Admissions::EoiForm do
  let(:lead) { admissions_staff }
  # Applications open in February: a round before then is out of round.
  let!(:round) do
    Fabricate(:admissions_round, name: 'Fellowship 2027', opens_on: Date.current - 30, invites_on: Date.current + 60)
  end
  let!(:notice) { set_privacy_notice('Test privacy notice.') }

  before do
    email_template(round, 'confirmation', subject: 'Test confirmation', body: 'Test confirmation body for {{round}}.')
    email_template(round, 'holding', subject: 'Test holding', body: 'Test holding body.')
  end

  def set_privacy_notice(body, by: lead)
    Admissions::FormText.create!(key: 'privacy_notice', body: body, created_by_user: by)
  end

  def submit(email: 'new.person@example.com', phone: nil)
    form = described_class.new(email: email, phone: phone)
    expect(form.save).to be(true), -> { form.errors.full_messages.to_sentence }
    form
  end

  def set_mode(type, mode, in_round: round)
    in_round.update!(email_modes: in_round.email_modes.merge(type => mode))
  end

  def kinds(applicant) = applicant.events.map(&:kind)

  describe 'a first EOI, out of round' do
    it 'creates the applicant at eoi, as the applicant, recording the privacy notice shown' do
      form = submit(email: '  New.Person@Example.com ', phone: ' +44 7700 900123 ')
      applicant = form.applicant

      expect(form.outcome).to eq :created
      expect(applicant).to have_attributes(round: round, stage: 'eoi', email: 'New.Person@Example.com',
                                           phone: '+44 7700 900123', name: nil, previous_applicant: nil)
      created = applicant.events.first
      expect(created).to have_attributes(kind: 'created', actor_type: 'applicant', actor_user: nil, to_stage: 'eoi')
      expect(created.details).to eq('via' => 'eoi_form', 'privacy_notice_version' => notice.id)
    end

    it 'stores no phone when none is given' do
      expect(submit(phone: '  ').applicant.phone).to be_nil
    end

    it 'holds the confirmation and the holding email on ask me first, the default' do
      applicant = submit.applicant

      expect(applicant.emails.map { |e| [e.email_type, e.status] }).to eq [%w[confirmation held], %w[holding held]]
      expect(recorded_emails).to be_empty
      expect(kinds(applicant)).to eq %w[created email_drafted email_drafted]
    end

    it 'sends both on automatic, once the EOI has saved' do
      set_mode('confirmation', 'automatic')
      set_mode('holding', 'automatic')
      applicant = submit.applicant

      expect(applicant.emails.map(&:status)).to eq %w[sent sent]
      expect(recorded_emails.map(&:subject)).to eq ['Test confirmation', 'Test holding']
      expect(recorded_emails.map(&:to).uniq).to eq ['new.person@example.com']
      expect(recorded_emails.first.body).to eq 'Test confirmation body for Fellowship 2027.'
    end

    it 'drafts nothing for a type that is off, and says so' do
      set_mode('confirmation', 'off')
      set_mode('holding', 'off')
      applicant = submit.applicant

      expect(applicant.emails).to be_empty
      expect(applicant.events.where(kind: 'email_skipped').map { |e| e.details.values_at('email_type', 'reason') })
        .to eq [%w[confirmation off], %w[holding off]]
    end

    it 'follows each type’s own mode' do
      set_mode('confirmation', 'automatic')
      set_mode('holding', 'off')
      applicant = submit.applicant

      expect(applicant.emails.map { |e| [e.email_type, e.status] }).to eq [%w[confirmation sent]]
      expect(recorded_emails.size).to eq 1
    end
  end

  describe 'a first EOI while applications are open' do
    before { round.update!(invites_on: Date.current) }

    it 'gets the confirmation only, and no invitation yet (phase 2)' do
      set_mode('confirmation', 'automatic')
      set_mode('holding', 'automatic')
      applicant = submit.applicant

      expect(applicant.stage).to eq 'eoi'
      expect(applicant.emails.map(&:email_type)).to eq %w[confirmation]
      expect(recorded_emails.map(&:subject)).to eq ['Test confirmation']
      expect(kinds(applicant)).to eq %w[created email_drafted email_sending email_sent]
    end

    it 'holds the confirmation on ask me first' do
      expect(submit.applicant.emails.map { |e| [e.email_type, e.status] }).to eq [%w[confirmation held]]
    end
  end

  describe 'an email that cannot be drafted' do
    it 'still saves the EOI when there is no template, logging why' do
      Admissions::EmailTemplate.where(round: round).delete_all
      applicant = submit.applicant

      expect(applicant).to be_persisted
      expect(applicant.emails).to be_empty
      expect(applicant.events.where(kind: 'email_not_drafted').map { |e| e.details.values_at('email_type', 'reason') })
        .to eq [%w[confirmation missing_template], %w[holding missing_template]]
    end

    it 'still saves the EOI when a placeholder cannot be filled ({{name}}: an EOI has no name)' do
      round.email_template('confirmation').update!(body: 'Dear {{name}}')
      applicant = submit.applicant

      expect(applicant).to be_persisted
      expect(applicant.events.find_by(kind: 'email_not_drafted').details['reason']).to eq 'placeholder_unfilled'
      expect(applicant.emails.map(&:email_type)).to eq %w[holding]
    end
  end

  describe 'a rollback' do
    it 'sends nothing and keeps nothing when the EOI fails after its emails were asked for' do
      set_mode('confirmation', 'automatic')
      allow(Admissions::EmailSender).to receive(:request_automatic!).and_call_original
      allow(Admissions::EmailSender).to receive(:request_automatic!).with(anything, 'holding').and_raise('boom')

      expect { described_class.new(email: 'new.person@example.com').save }.to raise_error('boom')

      expect(recorded_emails).to be_empty
      expect(Admissions::Applicant.count).to eq 0
      expect(Admissions::Email.count).to eq 0
      expect(Admissions::ApplicantEvent.count).to eq 0
    end
  end

  describe 'the same address again in the same round' do
    let!(:first) { submit(email: 'repeat@example.com', phone: '020 7946 0000').applicant }

    it 'makes no second record, logs the repeat on the first, and sends nothing new' do
      set_mode('confirmation', 'automatic')
      set_mode('holding', 'automatic')
      form = Timecop.freeze(1.day.from_now) { submit(email: 'REPEAT@Example.COM') }

      expect(form.outcome).to eq :repeated
      expect(form.applicant).to eq first
      expect(Admissions::Applicant.count).to eq 1
      repeat = first.events.last
      expect(repeat).to have_attributes(kind: 'eoi_repeated', actor_type: 'applicant', body: nil,
                                        created_at: be_within(1.minute).of(1.day.from_now))
      expect(repeat.details).to eq('new_phone' => false)
      expect(first.emails.map(&:status)).to eq %w[held held]
      expect(recorded_emails).to be_empty
    end

    it 'keeps a new phone number in the event for staff, without changing the record' do
      submit(email: 'repeat@example.com', phone: '07700 900456')

      expect(first.reload.phone).to eq '020 7946 0000'
      repeat = first.events.last
      expect(repeat.details).to eq('new_phone' => true)
      expect(repeat.body).to eq 'Phone number given: 07700 900456'
    end

    it 'logs a repeat even after the applicant has moved on or deferred' do
      staff_changes(lead).exit!(first, to: 'deferred')
      expect(submit(email: 'repeat@example.com').outcome).to eq :repeated
      expect(first.reload.stage).to eq 'deferred'
    end
  end

  describe 'someone from an earlier round' do
    let(:earlier_round) { Fabricate(:admissions_round, name: 'Fellowship 2026') }

    before do
      earlier_round.update!(closed_at: 1.month.ago)
    end

    it 'gets a fresh record in this round, linked to their earlier one' do
      earlier = create_applicant(round: earlier_round, email: 'returning@example.com')
      staff_changes(lead).exit!(earlier, to: 'deferred')

      applicant = submit(email: 'Returning@example.com').applicant

      expect(applicant).not_to eq earlier
      expect(applicant).to have_attributes(round: round, stage: 'eoi', previous_applicant: earlier)
      expect(applicant.person_records).to eq [earlier, applicant]
      expect(earlier.reload.stage).to eq 'deferred'
    end

    it 'links to their latest earlier record' do
      oldest_round = Fabricate(:admissions_round, name: 'Fellowship 2025')
      oldest_round.update!(closed_at: 1.year.ago)
      oldest = create_applicant(round: oldest_round, email: 'returning@example.com')
      earlier = create_applicant(round: earlier_round, email: 'returning@example.com', previous_applicant: oldest)

      expect(submit(email: 'returning@example.com').applicant.previous_applicant).to eq earlier
    end
  end

  describe 'a withdrawn applicant' do
    it 'comes back as a new record, since withdrawal scrubbed the old one' do
      withdrawn = submit(email: 'withdrawn@example.com').applicant
      staff_changes(lead).withdraw!(withdrawn)
      expect(withdrawn.reload.email).to be_nil

      form = submit(email: 'withdrawn@example.com')

      expect(form.outcome).to eq :created
      expect(form.applicant).not_to eq withdrawn
      expect(form.applicant).to have_attributes(email: 'withdrawn@example.com', stage: 'eoi', previous_applicant: nil)
      expect(kinds(withdrawn.reload)).not_to include('eoi_repeated')
    end
  end

  describe 'which round' do
    it 'is the earliest unclosed round by opening date' do
      Fabricate(:admissions_round, name: 'Fellowship 2028', opens_on: round.opens_on + 365,
                                   invites_on: nil, closes_on: nil)
      Fabricate(:admissions_round, name: 'Undated', opens_on: nil, invites_on: nil, closes_on: nil)
      Fabricate(:admissions_round, name: 'Fellowship 2026', opens_on: round.opens_on - 365,
                                   invites_on: nil, closes_on: nil)
        .update!(closed_at: 1.day.ago)

      expect(described_class.round).to eq round
      expect(submit.applicant.round).to eq round
    end

    it 'puts rounds with no opening date last, then goes by age' do
      round.update!(closed_at: 1.day.ago)
      undated = Fabricate(:admissions_round, name: 'Undated', opens_on: nil, invites_on: nil, closes_on: nil)
      Fabricate(:admissions_round, name: 'Undated later', opens_on: nil, invites_on: nil, closes_on: nil)
      expect(described_class.round).to eq undated
    end
  end

  describe 'when the form is closed' do
    it 'is closed with no round left open, and saves nothing' do
      round.update!(closed_at: 1.day.ago)

      expect(described_class.closed_reasons).to eq [:no_open_round]
      expect { described_class.new(email: 'new.person@example.com').save }.to raise_error(described_class::Closed)
      expect(Admissions::Applicant.count).to eq 0
    end

    context 'with no privacy notice' do
      let!(:notice) { nil }

      it 'is closed, and saves nothing' do
        Admissions::FormText.create!(key: 'eoi_introduction', body: 'Test introduction.', created_by_user: lead)

        expect(described_class.closed_reasons).to eq [:no_privacy_notice]
        expect { described_class.new(email: 'new.person@example.com').save }.to raise_error(described_class::Closed)
        expect(Admissions::Applicant.count).to eq 0
      end

      it 'names both reasons when both are missing' do
        round.update!(closed_at: 1.day.ago)
        expect(described_class.closed_reasons).to eq %i[no_privacy_notice no_open_round]
        expect(described_class).not_to be_open
      end
    end

    it 'records the privacy notice current when the EOI arrives' do
      newer = set_privacy_notice('A newer test notice.')
      expect(submit.applicant.events.first.details['privacy_notice_version']).to eq newer.id
    end
  end

  describe 'validation' do
    def errors_for(**attrs)
      form = described_class.new(**attrs)
      expect(form.save).to be false
      form.errors.to_hash
    end

    it 'needs an email address' do
      expect(errors_for(email: ' ')).to eq(email: ['Please enter your email address.'])
    end

    ['not-an-email', 'two@@example.com', 'name@gmail', 'a b@example.com', "#{'a' * 250}@example.com"].each do |bad|
      it "refuses #{bad.truncate(30).inspect} as an email address" do
        expect(errors_for(email: bad))
          .to eq(email: ["That doesn't look like an email address. Please check it."])
      end
    end

    ['+44 (0)20 7946 0000', '07700900123', '+1-202-555-0143 ext. 12', '020.7946.0000'].each do |phone|
      it "accepts #{phone.inspect} as a phone number" do
        expect(submit(phone: phone).applicant.phone).to eq phone
      end
    end

    ['12345', 'call me', '1' * 41].each do |bad|
      it "refuses #{bad.inspect} as a phone number" do
        expect(errors_for(email: 'ok@example.com', phone: bad))
          .to eq(phone: ["That doesn't look like a phone number. You can leave it blank."])
      end
    end

    it 'saves nothing when invalid' do
      errors_for(email: 'nope')
      expect(Admissions::Applicant.count).to eq 0
    end
  end
end
