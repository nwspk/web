require 'rails_helper'

RSpec.describe Admissions::Round, 'settings' do
  let(:round) { Fabricate(:admissions_round) }

  describe 'email modes' do
    it 'starts every SPEC §4 type on ask me first' do
      expect(Admissions::EmailTypes.keys.map { |t| round.email_mode(t) }).to all(eq 'ask_me_first')
      expect(Admissions::EmailTypes.keys).to include('confirmation', 'holding', 'reminder', 'round_close',
                                                     'next_round_reminder', 'events_digest', 'offer')
    end

    it 'takes only known types and modes' do
      expect(round.update(email_modes: { 'confirmation' => 'automatic', 'holding' => 'off' })).to be true
      expect(round.update(email_modes: { 'confirmation' => 'loudly' })).to be false
      expect(round.update(email_modes: { 'unknown' => 'off' })).to be false
      expect { round.email_mode('unknown') }.to raise_error(ArgumentError)
    end

    it 'keeps wording out of code: types are keys with staff-facing names only' do
      expect(Admissions::EmailTypes::TYPES.values).to all(satisfy { |label| label.length < 50 })
    end
  end

  describe 'timings' do
    it 'defaults to 7 days for the reminder and every staff-waiting stage' do
      expect(round.reminder_interval).to eq 7.days
      expect(described_class.staff_stages).to eq %w[eoi applied task_returned interviewed accepted]
      expect(described_class.staff_stages.map { |s| round.staff_turnaround(s) }).to all(eq 7.days)
    end

    it 'validates them' do
      expect(round.update(reminder_interval_days: 0)).to be false
      expect(round.reload.update(staff_turnaround_days: { 'applied' => 0 })).to be false
      expect(round.reload.update(staff_turnaround_days: { 'invited' => 3 })).to be false
      expect(round.reload.update(staff_turnaround_days: { 'applied' => '3' })).to be false
      expect(round.reload.update(staff_turnaround_days: { 'applied' => 3 })).to be true
      expect { round.staff_turnaround('invited') }.to raise_error(ArgumentError)
    end

    it 'drives the next step: the reminder and the staff turnaround come from the round' do
      round.update!(reminder_interval_days: 3, staff_turnaround_days: { 'applied' => 2 })
      Timecop.freeze(Time.zone.local(2026, 11, 3, 10)) do
        invited = create_applicant(round: round, stage: 'invited')
        applied = create_applicant(round: round, stage: 'applied')
        interviewed = create_applicant(round: round, stage: 'interviewed')
        expect(invited.next_step.due_at).to eq Time.zone.local(2026, 11, 6, 10)
        expect(applied.next_step.due_at).to eq Time.zone.local(2026, 11, 5, 10)
        expect(interviewed.next_step.due_at).to eq Time.zone.local(2026, 11, 10, 10)
      end
    end

    it 'drives the EOI turnaround once applications are open' do
      round.update!(staff_turnaround_days: { 'eoi' => 1 })
      Timecop.freeze(Time.zone.local(2027, 2, 3, 9)) do
        eoi = create_applicant(round: round, stage: 'eoi')
        expect(eoi.next_step).to have_attributes(owner: :staff, due_at: Time.zone.local(2027, 2, 4, 9))
      end
    end
  end

  describe 'money' do
    it 'keeps pence and gives Money in GBP' do
      round.update!(programme_fee_pence: 300_000)
      expect(round.programme_fee).to eq Money.new(300_000, 'GBP')
      expect(round.programme_fee.format).to eq '£3000.00'
      expect(round.scholarship_pot).to be_nil
    end

    it 'reads pounds as typed' do
      round.update!(programme_fee_pounds: '£3,000', accommodation_monthly_pounds: '1100.5', scholarship_pot_pounds: '')
      expect([round.programme_fee_pence, round.accommodation_monthly_pence, round.scholarship_pot_pence])
        .to eq [300_000, 110_050, nil]
      expect(round.programme_fee_pounds).to eq '3000'
    end

    it 'refuses what is not an amount, keeping it to show again' do
      expect(round.update(programme_fee_pounds: '3k')).to be false
      expect(round.errors[:programme_fee_pounds]).to be_present
      expect(round.programme_fee_pounds).to eq '3k'
      expect(round.update(accommodation_monthly_pounds: '1.234')).to be false
      expect(Fabricate.build(:admissions_round, programme_fee_pence: -1)).not_to be_valid
    end

    it 'forgets an earlier bad amount once a good one is typed' do
      round.programme_fee_pounds = 'lots'
      round.programme_fee_pounds = '2500'
      expect(round.save).to be true
      expect(round.reload.programme_fee_pence).to eq 250_000
    end
  end

  it 'lets only leads change settings' do
    expect(Ability.new(admissions_staff(role: 'lead')).can?(:update, round)).to be true
    expect(Ability.new(admissions_staff(role: 'officer')).can?(:update, round)).to be false
    expect(Ability.new(admissions_staff(role: 'officer')).can?(:read, round)).to be true
  end
end
