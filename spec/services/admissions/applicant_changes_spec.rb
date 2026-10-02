require 'rails_helper'

RSpec.describe Admissions::ApplicantChanges do
  illegal = described_class::IllegalChange
  not_permitted = described_class::NotPermitted

  let(:round) { Fabricate(:admissions_round) }
  let(:lead) { admissions_staff(role: 'lead') }
  let(:staff) { staff_changes(lead) }
  let(:as_system) { system_changes }

  def changes_for(actor_type, applicant)
    { 'staff' => staff, 'applicant' => applicant_changes(applicant), 'system' => as_system }.fetch(actor_type)
  end

  # Whatever a test did, every applicant's cached state must still agree with
  # what its log rebuilds (SPEC §1: the log is the truth).
  after do
    Admissions::Applicant.find_each do |applicant|
      expect(Admissions::StateRebuilder.discrepancies(applicant)).to eq({}), 
"applicant #{applicant.id} disagrees with its log"
    end
  end

  describe 'who may act as staff' do
    it 'accepts a lead and an officer' do
      expect { staff_changes(admissions_staff(role: 'lead')) }.not_to raise_error
      expect { staff_changes(admissions_staff(role: 'officer')) }.not_to raise_error
    end

    it 'refuses a site user without an admissions role, even a site admin' do
      expect { staff_changes(Fabricate(:user, role: 'admin')) }.to raise_error(not_permitted)
      expect { staff_changes(Fabricate(:user, role: 'staff')) }.to raise_error(not_permitted)
      expect { staff_changes(Fabricate(:user)) }.to raise_error(not_permitted)
    end

    it 'accepts a site admin who also holds an admissions role' do
      user = Fabricate(:user, role: 'admin')
      Fabricate(:admissions_staff_member, user: user, role: 'officer')
      expect { staff_changes(user) }.not_to raise_error
    end

    it 'refuses a staff actor without a user, and a user on a non-staff actor' do
      expect { described_class.new(Admissions::Actor.staff(nil)) }.to raise_error(not_permitted)
      expect { described_class.new(Admissions::Actor.new('applicant', lead)) }.to raise_error(ArgumentError)
      expect { described_class.new(Admissions::Actor.new('ed', nil)) }.to raise_error(ArgumentError)
      expect { described_class.new(:system) }.to raise_error(ArgumentError)
    end
  end

  describe '#create!' do
    it 'creates an EOI from the applicant with a created event' do
      applicant = applicant_changes.create!(round: round, email: 'someone@example.org')

      expect(applicant).to be_persisted
      expect(applicant.stage).to eq 'eoi'
      expect(applicant.events.map(&:kind)).to eq ['created']
      expect(applicant.events.first).to have_attributes(actor_type: 'applicant', actor_user: nil, to_stage: 'eoi')
    end

    Admissions::Stages::FUNNEL.each do |stage|
      it "lets staff create a card by hand at #{stage}" do
        applicant = staff.create!(round: round, email: Faker::Internet.email, stage: stage)
        expect(applicant.stage).to eq stage
        expect(applicant.events.first).to have_attributes(kind: 'created', actor_type: 'staff', actor_user: lead)
      end
    end

    it 'lets only staff create past eoi' do
      expect {
 applicant_changes.create!(round: round, email: Faker::Internet.email, stage: 'applied') }.to raise_error(not_permitted)
      expect { as_system.create!(round: round, email: Faker::Internet.email) }.to raise_error(not_permitted)
    end

    it 'does not create at on_hold or an exit state' do
      (Admissions::Stages::EXITS + [Admissions::Stages::ON_HOLD]).each do |stage|
        expect { staff.create!(round: round, email: Faker::Internet.email, stage: stage) }.to raise_error(illegal)
      end
    end

    it 'requires a valid email, unique within the round regardless of case' do
      expect { staff.create!(round: round, email: '') }.to raise_error(ActiveRecord::RecordInvalid)
      expect { staff.create!(round: round, email: 'not an email') }.to raise_error(ActiveRecord::RecordInvalid)
      staff.create!(round: round, email: 'Same@Example.org')
      expect { staff.create!(round: round, email: 'same@example.org') }.to raise_error(ActiveRecord::RecordInvalid)
      expect { staff.create!(round: Fabricate(:admissions_round), email: 'same@example.org') }.not_to raise_error
      expect(Admissions::ApplicantEvent.count).to eq 2
    end

    it "links a re-applicant to an earlier round's record" do
      earlier = create_applicant(round: Fabricate(:admissions_round))
      later = staff.create!(round: round, email: earlier.email, previous_applicant: earlier)
      expect(later.previous_applicant).to eq earlier
      expect(earlier.later_applicants).to eq [later]
    end
  end

  describe '#advance!' do
    Admissions::Stages::TRANSITIONS.each do |(from, to), actors|
      actors.each do |actor_type|
        it "#{from} → #{to} by #{actor_type}" do
          applicant = applicant_at(from)
          Timecop.freeze(1.day.from_now) do
            changes_for(actor_type, applicant).advance!(applicant, to: to)
          end
          applicant.reload
          expect(applicant.stage).to eq to
          expect(applicant.stage_entered_at).to be > 12.hours.from_now
          event = applicant.events.last
          expect(event).to have_attributes(kind: 'advanced', from_stage: from, to_stage: to, actor_type: actor_type)
          expect(event.actor_user).to eq(actor_type == 'staff' ? lead : nil)
        end
      end

      (Admissions::Stages::ACTOR_TYPES - actors).each do |actor_type|
        it "refuses #{from} → #{to} by #{actor_type}" do
          applicant = applicant_at(from)
          expect { changes_for(actor_type, applicant).advance!(applicant, to: to) }.to raise_error(not_permitted)
          expect(applicant.reload.stage).to eq from
          expect(applicant.events.count).to eq 1
        end
      end
    end

    it 'allows staff every legal transition' do
      expect(Admissions::Stages::TRANSITIONS.values).to all(include('staff'))
    end

    it 'walks the whole happy path from eoi to confirmed' do
      applicant = create_applicant
      path = Admissions::Stages::FUNNEL.drop(1)
      path.each { |stage| staff.advance!(applicant, to: stage) }
      expect(applicant.reload.stage).to eq 'confirmed'
      expect(applicant.events.map(&:to_stage)).to eq Admissions::Stages::FUNNEL
    end

    Admissions::Stages::ALL.each do |from|
      targets = Admissions::Stages::ALL.reject { |to| Admissions::Stages.transition?(from, to) }
      it "refuses every illegal step from #{from} (#{targets.size} targets), even for staff" do
        applicant = applicant_at(from)
        events = applicant.events.count
        targets.each do |to|
          expect { staff.advance!(applicant, to: to) }.to raise_error(illegal), "#{from} → #{to} was allowed"
        end
        expect(applicant.reload.stage).to eq from
        expect(applicant.events.count).to eq events
      end
    end

    it 'refuses an unknown stage' do
      expect { staff.advance!(create_applicant, to: 'interviewing') }.to raise_error(illegal)
    end

    it 'acts on the stored stage, not a stale copy' do
      applicant = create_applicant
      stale = Admissions::Applicant.find(applicant.id)
      staff.advance!(applicant, to: 'invited')
      expect { staff.advance!(stale, to: 'invited') }.to raise_error(illegal)
      staff.advance!(stale, to: 'applied')
      expect(applicant.reload.stage).to eq 'applied'
    end
  end

  describe 'on hold' do
    let(:until_date) { Date.current + 30 }

    Admissions::Stages::FUNNEL.reject { |s| Admissions::Stages.terminal?(s) }.each do |stage|
      it "holds from #{stage} and returns to #{stage}" do
        applicant = applicant_at(stage)
        applicant_changes(applicant).hold!(applicant, until_date: until_date, reason: 'Waiting to hear about a job')
        applicant.reload
        expect(applicant).to have_attributes(stage: 'on_hold', held_from_stage: stage, hold_until: until_date,
                                             hold_reason: 'Waiting to hear about a job', funnel_stage: stage)
        expect(applicant.events.last).to have_attributes(kind: 'held', from_stage: stage, to_stage: 'on_hold',
                                                         body: 'Waiting to hear about a job',
                                                         details: { 'hold_until' => until_date.iso8601 })

        staff.return_from_hold!(applicant)
        applicant.reload
        expect(applicant).to have_attributes(stage: stage, held_from_stage: nil, hold_until: nil, hold_reason: nil)
        expect(applicant.events.last).to have_attributes(kind: 'returned_from_hold', from_stage: 'on_hold', to_stage: stage,
                                                         actor_type: 'staff', actor_user: lead)
      end
    end

    (Admissions::Stages::TERMINAL + [Admissions::Stages::ON_HOLD]).each do |stage|
      it "cannot hold from #{stage}" do
        applicant = applicant_at(stage)
        expect { staff.hold!(applicant, until_date: until_date, reason: 'x') }.to raise_error(illegal)
      end
    end

    it 'needs a reason and a return date after today' do
      applicant = create_applicant
      expect { staff.hold!(applicant, until_date: until_date, reason: ' ') }.to raise_error(illegal)
      expect { staff.hold!(applicant, until_date: Date.current, reason: 'x') }.to raise_error(illegal)
      expect { staff.hold!(applicant, until_date: nil, reason: 'x') }.to raise_error(illegal)
      expect { staff.hold!(applicant, until_date: '2030-01-01', reason: 'x') }.to raise_error(illegal)
      expect(applicant.reload.stage).to eq 'eoi'
    end

    it 'is set by the applicant or staff, not the system' do
      expect { as_system.hold!(create_applicant, until_date: until_date, reason: 'x') }.to raise_error(not_permitted)
    end

    it 'lets the applicant return early, but not the system' do
      applicant = applicant_at('on_hold')
      expect { as_system.return_from_hold!(applicant) }.to raise_error(not_permitted)
      applicant_changes(applicant).return_from_hold!(applicant)
      expect(applicant.reload.stage).to eq 'applied'
    end

    it 'cannot return an applicant who is not on hold' do
      expect { staff.return_from_hold!(create_applicant) }.to raise_error(illegal)
    end

    it 'blocks funnel steps until the applicant returns' do
      applicant = applicant_at('on_hold')
      expect { staff.advance!(applicant, to: 'task_sent') }.to raise_error(illegal)
    end
  end

  describe "it's complicated" do
    it 'is a flag: the stage and any hold stay as they were' do
      applicant = applicant_at('on_hold')
      staff.flag_complicated!(applicant, note: 'Depends on a visa decision', check_back_on: Date.current + 10)
      applicant.reload
      expect(applicant).to have_attributes(stage: 'on_hold', held_from_stage: 'applied', complicated: true,
                                           complicated_note: 'Depends on a visa decision',
                                           complicated_check_back_on: Date.current + 10)
      expect(applicant.events.last).to have_attributes(kind: 'flagged_complicated', from_stage: nil, to_stage: nil,
                                                       details: { 'check_back_on' => (Date.current + 10).iso8601 })
    end

    it 'survives stage changes and clears back to the same stage' do
      applicant = create_applicant(stage: 'applied')
      staff.flag_complicated!(applicant, note: 'Knows a fellow', check_back_on: Date.current)
      staff.advance!(applicant, to: 'task_sent')
      expect(applicant.reload).to have_attributes(stage: 'task_sent', complicated: true)

      staff.clear_complicated!(applicant)
      expect(applicant.reload).to have_attributes(stage: 'task_sent', complicated: false, complicated_note: nil,
                                                  complicated_check_back_on: nil)
      expect(applicant.events.last.kind).to eq 'cleared_complicated'
    end

    it 'can be re-flagged with a new note and date' do
      applicant = create_applicant
      staff.flag_complicated!(applicant, note: 'First', check_back_on: Date.current)
      staff.flag_complicated!(applicant, note: 'Second', check_back_on: Date.current + 5)
      expect(applicant.reload).to have_attributes(complicated_note: 'Second', 
complicated_check_back_on: Date.current + 5)
    end

    it 'needs a note and a check-back date not in the past' do
      applicant = create_applicant
      expect { staff.flag_complicated!(applicant, note: '', check_back_on: Date.current) }.to raise_error(illegal)
      expect { staff.flag_complicated!(applicant, note: 'x', check_back_on: nil) }.to raise_error(illegal)
      expect { staff.flag_complicated!(applicant, note: 'x', check_back_on: Date.current - 1) }.to raise_error(illegal)
    end

    it 'is staff-only' do
      applicant = create_applicant
      expect {
 applicant_changes(applicant).flag_complicated!(applicant, note: 'x', check_back_on: Date.current) }.to raise_error(not_permitted)
      expect {
 as_system.flag_complicated!(applicant, note: 'x', check_back_on: Date.current) }.to raise_error(not_permitted)
      staff.flag_complicated!(applicant, note: 'x', check_back_on: Date.current)
      expect { applicant_changes(applicant).clear_complicated!(applicant) }.to raise_error(not_permitted)
    end

    it 'cannot be set on an exit state, or cleared when not set' do
      expect { staff.flag_complicated!(applicant_at('rejected'), note: 'x', check_back_on: Date.current) }
        .to raise_error(illegal)
      expect { staff.clear_complicated!(create_applicant) }.to raise_error(illegal)
    end
  end

  describe '#move! (move to any stage)' do
    it 'fast-tracks past stages' do
      applicant = create_applicant
      staff.move!(applicant, to: 'interview_offered', note: 'Met at an event')
      expect(applicant.reload.stage).to eq 'interview_offered'
      expect(applicant.events.last).to have_attributes(kind: 'moved', from_stage: 'eoi', to_stage: 'interview_offered',
                                                       actor_user: lead, body: 'Met at an event',
                                                       details: { 'emails' => [] })
    end

    it 'moves backwards to correct a mistake' do
      applicant = create_applicant(stage: 'interviewed')
      staff.move!(applicant, to: 'task_sent')
      expect(applicant.reload.stage).to eq 'task_sent'
    end

    Admissions::Stages::ALL.each do |from|
      next if from == 'withdrawn'

      it "moves from #{from} to every other funnel stage" do
        (Admissions::Stages::FUNNEL - [from]).each do |to|
          applicant = applicant_at(from, round: round)
          staff.move!(applicant, to: to)
          expect(applicant.reload).to have_attributes(stage: to, held_from_stage: nil, hold_until: nil,
                                                      hold_reason: nil, exited_from_stage: nil)
        end
      end
    end

    it 'ends a hold but keeps the complicated flag' do
      applicant = applicant_at('on_hold')
      staff.flag_complicated!(applicant, note: 'x', check_back_on: Date.current)
      staff.move!(applicant, to: 'applied')
      expect(applicant.reload).to have_attributes(stage: 'applied', held_from_stage: nil, complicated: true)
    end

    it 'refuses moves to on_hold, exits, the same stage, or from withdrawn' do
      applicant = create_applicant
      expect { staff.move!(applicant, to: 'on_hold') }.to raise_error(illegal)
      expect { staff.move!(applicant, to: 'rejected') }.to raise_error(illegal)
      expect { staff.move!(applicant, to: 'eoi') }.to raise_error(illegal)
      expect { staff.move!(applicant_at('withdrawn'), to: 'eoi') }.to raise_error(illegal)
    end

    it 'is staff-only' do
      applicant = create_applicant
      expect { applicant_changes(applicant).move!(applicant, to: 'offered') }.to raise_error(not_permitted)
      expect { as_system.move!(create_applicant, to: 'offered') }.to raise_error(not_permitted)
    end

    it 'previews the move, with no emails until email-sender exists' do
      applicant = create_applicant
      preview = staff.preview_move(applicant, to: 'interview_offered')
      expect(preview).to have_attributes(from: 'eoi', to: 'interview_offered', emails: [])
      expect(applicant.reload.events.count).to eq 1
    end

    it 'refuses to send an email the preview did not offer' do
      applicant = create_applicant
      expect { staff.move!(applicant, to: 'invited', emails: ['invitation']) }.to raise_error(illegal)
      expect(applicant.reload.stage).to eq 'eoi'
    end
  end

  describe '#exit!' do
    exit_cases = Admissions::Stages::EXIT_ACTORS
    exit_cases.each do |to, actors|
      (Admissions::Stages::ALL - Admissions::Stages::EXITS).each do |from|
        it "#{from} → #{to}" do
          applicant = applicant_at(from)
          staff.exit!(applicant, to: to)
          applicant.reload
          expect(applicant.stage).to eq to
          expect(applicant.exited_from_stage).to eq(from == 'on_hold' ? 'applied' : from)
          expect(applicant).to have_attributes(held_from_stage: nil, hold_until: nil, hold_reason: nil)
          expect(applicant.events.last).to have_attributes(kind: 'exited', from_stage: from, to_stage: to)
        end
      end

      actors.each do |actor_type|
        it "lets #{actor_type} exit to #{to}" do
          applicant = create_applicant(stage: 'offered')
          changes_for(actor_type, applicant).exit!(applicant, to: to)
          expect(applicant.reload.stage).to eq to
          expect(applicant.events.last.actor_type).to eq actor_type
        end
      end

      (Admissions::Stages::ACTOR_TYPES - actors).each do |actor_type|
        it "refuses #{to} by #{actor_type}" do
          applicant = create_applicant(stage: 'offered')
          expect { changes_for(actor_type, applicant).exit!(applicant, to: to) }.to raise_error(not_permitted)
          expect(applicant.reload.stage).to eq 'offered'
        end
      end
    end

    %w[deferred declined rejected].each do |from|
      it "withdraws from #{from}, keeping the stage it first exited from" do
        applicant = create_applicant(stage: 'task_sent')
        staff.exit!(applicant, to: from)
        staff.withdraw!(applicant)
        expect(applicant.reload).to have_attributes(stage: 'withdrawn', exited_from_stage: 'task_sent')
      end

      it "does not exit from #{from} to another non-withdrawn exit" do
        applicant = applicant_at(from)
        (Admissions::Stages::EXITS - [from, 'withdrawn']).each do |to|
          expect { staff.exit!(applicant, to: to) }.to raise_error(illegal)
        end
      end
    end

    it 'cannot withdraw twice, or exit to a non-exit' do
      expect { staff.withdraw!(applicant_at('withdrawn')) }.to raise_error(illegal)
      expect { staff.exit!(create_applicant, to: 'confirmed') }.to raise_error(illegal)
    end

    it 'records an optional note' do
      applicant = create_applicant(stage: 'interviewed')
      staff.exit!(applicant, to: 'rejected', note: 'Not eligible this year')
      expect(applicant.events.last.body).to eq 'Not eligible this year'
    end
  end

  describe 'withdrawal scrubs personal data' do
    let(:earlier) { create_applicant(round: Fabricate(:admissions_round)) }
    let!(:applicant) do
      create_applicant(stage: 'applied', round: round, previous_applicant: earlier).tap do |a|
        staff.add_note!(a, body: 'Mentioned their employer by name')
        staff.hold!(a, until_date: Date.current + 7, reason: 'Waiting on a personal matter')
        staff.flag_complicated!(a, note: 'Family situation', check_back_on: Date.current + 3)
      end
    end
    let!(:later) { create_applicant(round: Fabricate(:admissions_round), previous_applicant: applicant) }

    before { applicant_changes(applicant).withdraw!(applicant) }

    it 'blanks the personal fields and free text, keeping an anonymised stub' do
      expect(applicant.email).to be_nil # the object passed in is reloaded
      applicant.reload
      expect(applicant).to have_attributes(email: nil, phone: nil, name: nil, hold_reason: nil, complicated: false,
                                           complicated_note: nil, complicated_check_back_on: nil,
                                           stage: 'withdrawn', exited_from_stage: 'applied')
      expect(applicant.round).to eq round
    end

    it "blanks the free text in the applicant's events but keeps the events" do
      events = applicant.events.reload
      expect(events.map(&:kind)).to eq %w[created note_added held flagged_complicated cleared_complicated exited]
      expect(events.map(&:body)).to all(be_nil)
      expect(events.select(&:redacted_at).map(&:kind)).to eq %w[note_added held flagged_complicated]
      expect(events.last).to have_attributes(actor_type: 'applicant', to_stage: 'withdrawn')
    end

    it "keeps the links to the same person's records in other rounds, which keep their data" do
      expect(applicant.reload.previous_applicant).to eq earlier
      expect(later.reload.previous_applicant).to eq applicant
      expect(applicant.person_records).to eq [earlier, applicant, later]
      expect([earlier.reload.email, later.email]).to all(be_present)
    end

    it 'lets staff withdraw each linked record for a full erasure' do
      applicant.person_records.reject(&:withdrawn?).each { |record| staff.withdraw!(record) }
      expect([earlier, applicant, later].map { |r| r.reload.email }).to all(be_nil)
    end

    it "leaves other applicants' events alone" do
      staff.add_note!(later, body: 'Still here')
      expect(later.events.reload.last.body).to eq 'Still here'
    end

    it 'takes no further notes or details' do
      expect { staff.add_note!(applicant, body: 'x') }.to raise_error(illegal)
      expect { staff.update_details!(applicant, email: 'new@example.org') }.to raise_error(illegal)
    end
  end

  describe '#reopen!' do
    it 'returns a deferred applicant to the stage they deferred from' do
      applicant = create_applicant(stage: 'task_sent', round: round)
      applicant_changes(applicant).exit!(applicant, to: 'deferred')
      applicant_changes(applicant).reopen!(applicant)
      expect(applicant.reload).to have_attributes(stage: 'task_sent', exited_from_stage: nil)
      expect(applicant.events.last).to have_attributes(kind: 'reopened', from_stage: 'deferred', to_stage: 'task_sent')
    end

    it 'returns an applicant deferred while on hold to the stage they were held from' do
      applicant = applicant_at('on_hold')
      as_system.exit!(applicant, to: 'deferred')
      staff.reopen!(applicant)
      expect(applicant.reload.stage).to eq 'applied'
    end

    it 'lets the applicant reopen only while the round is open; staff always' do
      applicant = applicant_at('deferred', round: round)
      round.update!(closed_at: Time.current)
      expect { applicant_changes(applicant).reopen!(applicant) }.to raise_error(not_permitted)
      staff.reopen!(applicant)
      expect(applicant.reload.stage).to eq 'applied'
    end

    it 'is not done by the system, nor to anyone not deferred' do
      expect { as_system.reopen!(applicant_at('deferred')) }.to raise_error(not_permitted)
      %w[declined rejected withdrawn applied on_hold].each do |state|
        expect { staff.reopen!(applicant_at(state)) }.to raise_error(illegal)
      end
    end
  end

  describe '#add_note!' do
    it 'logs a note from staff without changing the stage' do
      applicant = create_applicant(stage: 'interviewed')
      staff.add_note!(applicant, body: 'Good conversation about civic tech')
      expect(applicant.reload.stage).to eq 'interviewed'
      expect(applicant.events.last).to have_attributes(kind: 'note_added', body: 'Good conversation about civic tech',
                                                       actor_user: lead)
    end

    it 'needs text and staff' do
      expect { staff.add_note!(create_applicant, body: '') }.to raise_error(illegal)
      applicant = create_applicant
      expect { applicant_changes(applicant).add_note!(applicant, body: 'x') }.to raise_error(not_permitted)
    end
  end

  describe '#update_details!' do
    it 'changes contact details and logs the field names, not the values' do
      applicant = create_applicant
      applicant_changes(applicant).update_details!(applicant, phone: '+44 20 7946 0000', name: 'A. N. Other')
      event = applicant.events.reload.last
      expect(event).to have_attributes(kind: 'details_changed', body: nil, details: { 'fields' => %w[phone name] })
      expect(event.attributes.values.join).not_to include('7946')
    end

    it 'logs nothing when nothing changed, and refuses other fields' do
      applicant = create_applicant
      staff.update_details!(applicant, email: applicant.email)
      expect(applicant.events.count).to eq 1
      expect { staff.update_details!(applicant, stage: 'confirmed') }.to raise_error(ArgumentError)
    end

    it 'validates the new email' do
      expect { staff.update_details!(create_applicant, email: 'nope') }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'event attribution' do
    it 'names the staff user who acted, for several staff' do
      officer = admissions_staff(role: 'officer')
      applicant = create_applicant(by: staff)
      staff_changes(officer).advance!(applicant, to: 'invited')
      applicant_changes(applicant).advance!(applicant, to: 'applied')
      as_system.exit!(applicant, to: 'deferred')

      expect(applicant.events.map { |e| [e.actor_type, e.actor_user] }).to eq [
        ['staff', lead], ['staff', officer], ['applicant', nil], ['system', nil]
      ]
    end
  end

  describe 'an applicant acts only on their own record' do
    it 'refuses an applicant actor acting on another record' do
      mine = create_applicant(stage: 'invited')
      theirs = create_applicant(stage: 'invited')
      expect { applicant_changes(mine).advance!(theirs, to: 'applied') }.to raise_error(not_permitted)
      expect { applicant_changes.advance!(theirs, to: 'applied') }.to raise_error(not_permitted)
      applicant_changes(mine.id).advance!(mine, to: 'applied')
      expect([mine.reload.stage, theirs.reload.stage]).to eq %w[applied invited]
    end

    it 'creates an EOI only as a new applicant' do
      existing = create_applicant
      expect { applicant_changes(existing).create!(round: round, email: Faker::Internet.email) }
        .to raise_error(not_permitted)
    end

    it 'names the applicant only on an applicant actor' do
      expect { described_class.new(Admissions::Actor.new('system', nil, 1)) }.to raise_error(ArgumentError)
      expect { described_class.new(Admissions::Actor.new('staff', lead, 1)) }.to raise_error(ArgumentError)
    end
  end

  describe "exits clear \"it's complicated\"" do
    %w[deferred declined rejected withdrawn].each do |to|
      it "clears the flag on #{to}, with its own event, so nobody is left flagged at a terminal stage" do
        applicant = create_applicant(stage: 'offered')
        staff.flag_complicated!(applicant, note: 'Unsure', check_back_on: Date.current + 3)
        applicant_changes(applicant).exit!(applicant, to: to) unless to == 'rejected'
        staff.exit!(applicant, to: to) if to == 'rejected'

        expect(applicant.reload).to have_attributes(stage: to, complicated: false, complicated_note: nil,
                                                    complicated_check_back_on: nil)
        expect(applicant.events.last(2).map(&:kind)).to eq %w[cleared_complicated exited]
        expect(applicant.events.last(2).map(&:actor_type).uniq).to eq [to == 'rejected' ? 'staff' : 'applicant']
        expect(applicant.next_step).to be_nil
      end
    end

    it 'logs no clearing when there was no flag' do
      applicant = create_applicant
      staff.exit!(applicant, to: 'deferred')
      expect(applicant.events.map(&:kind)).to eq %w[created exited]
    end
  end

  describe 'the object passed in' do
    it 'may be dirty: the change works on a fresh copy, then reloads it' do
      applicant = create_applicant
      applicant.name = 'Unsaved Name'
      staff.advance!(applicant, to: 'invited')
      expect(applicant).to have_attributes(stage: 'invited', changed?: false)
      expect(applicant.name).not_to eq 'Unsaved Name'
    end

    it 'is left exactly as it was when a change fails' do
      applicant = create_applicant
      applicant.name = 'Unsaved Name'
      expect { staff.advance!(applicant, to: 'confirmed') }.to raise_error(illegal)
      expect { staff.update_details!(applicant, email: 'bad') }.to raise_error(ActiveRecord::RecordInvalid)
      expect(applicant).to have_attributes(stage: 'eoi', name: 'Unsaved Name', changed?: true)
    end
  end

  describe 'a duplicate EOI race' do
    it 'turns the unique index violation into a validation error' do
      allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to receive(:validate_each)
      applicant_changes.create!(round: round, email: 'race@example.org')

      expect { applicant_changes.create!(round: round, email: 'RACE@example.org') }
        .to raise_error(ActiveRecord::RecordInvalid, /Email has already been taken/)
      expect(round.applicants.count).to eq 1
    end

    it 'does the same for a contact-detail change' do
      allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to receive(:validate_each)
      create_applicant(round: round, email: 'taken@example.org')
      other = create_applicant(round: round)
      expect { staff.update_details!(other, email: 'taken@example.org') }.to raise_error(ActiveRecord::RecordInvalid)
      expect(other.reload.email).not_to eq 'taken@example.org'
    end
  end

  describe 'the service write permission' do
    it 'is on only inside a change, never after one, whether it succeeds or fails' do
      applicant = create_applicant
      seen = nil
      allow(Admissions::ApplicantEvent).to receive(:create!).and_wrap_original do |original, **args|
        seen = Admissions::Applicant.service_write_allowed?
        original.call(**args)
      end
      staff.advance!(applicant, to: 'invited')
      expect(seen).to be true
      expect(Admissions::Applicant.service_write_allowed?).to be false
      expect { staff.advance!(applicant, to: 'confirmed') }.to raise_error(illegal)
      expect(Admissions::Applicant.service_write_allowed?).to be false
    end
  end

  describe 'atomicity' do
    it 'writes neither the event nor the stage when the save fails' do
      applicant = create_applicant
      allow(Admissions::ApplicantEvent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      expect { staff.advance!(applicant, to: 'invited') }.to raise_error(ActiveRecord::RecordInvalid)
      expect(applicant.reload.stage).to eq 'eoi'
    end

    it 'writes no event when the applicant row fails validation' do
      applicant = create_applicant
      expect { staff.update_details!(applicant, email: 'bad') }.to raise_error(ActiveRecord::RecordInvalid)
      expect(applicant.events.count).to eq 1
    end
  end
end
