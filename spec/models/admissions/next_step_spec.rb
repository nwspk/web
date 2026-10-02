require 'rails_helper'

RSpec.describe Admissions::NextStep do
  let(:round) { Fabricate(:admissions_round, invites_on: Date.new(2027, 2, 1)) }
  let(:staff) { staff_changes }
  let(:entered) { Time.zone.local(2026, 11, 3, 10, 30) }

  around { |example| Timecop.freeze(entered) { example.run } }

  def step_at(stage)
    applicant_at(stage, round: round).next_step
  end

  {
    'invited' => 'Applicant to complete the application form',
    'task_sent' => 'Applicant to return their task answer',
    'interview_offered' => 'Applicant to book an interview slot',
    'offered' => 'Applicant to accept or decline the offer',
    'contracts_sent' => 'Applicant to sign the contracts'
  }.each do |stage, description|
    it "#{stage} waits on the applicant, due at their next reminder" do
      expect(step_at(stage)).to have_attributes(owner: :applicant, due_at: entered + 7.days, description: description)
    end
  end

  %w[applied task_returned interviewed accepted].each do |stage|
    it "#{stage} waits on staff, due after the turnaround target" do
      expect(step_at(stage)).to have_attributes(owner: :staff, due_at: entered + 7.days)
    end
  end

  it 'eoi before applications open waits on the invitation date' do
    expect(step_at('eoi')).to have_attributes(owner: :date, due_at: Time.zone.local(2027, 2, 1))
  end

  it 'eoi after applications open waits on staff, due a turnaround after opening or arrival' do
    applicant = applicant_at('eoi', round: round)
    Timecop.freeze(Time.zone.local(2027, 2, 3, 9)) do
      expect(applicant.next_step).to have_attributes(owner: :staff, due_at: Time.zone.local(2027, 2, 8))
      late = applicant_at('eoi', round: round)
      expect(late.next_step).to have_attributes(owner: :staff, due_at: Time.zone.local(2027, 2, 10, 9))
    end
  end

  it 'eoi in a round with no invitation date has no due time' do
    applicant = applicant_at('eoi', round: Fabricate(:admissions_round, invites_on: nil))
    expect(applicant.next_step).to have_attributes(owner: :date, due_at: nil)
  end

  it 'interview_booked waits on a date it does not know yet' do
    expect(step_at('interview_booked')).to have_attributes(owner: :date, due_at: nil,
                                                           description: 'The interview to happen')
  end

  it 'on hold waits on the return date' do
    applicant = applicant_at('applied', round: round)
    staff.hold!(applicant, until_date: Date.new(2026, 12, 1), reason: 'r')
    expect(applicant.next_step).to have_attributes(owner: :date, due_at: Time.zone.local(2026, 12, 1))
  end

  it "it's complicated waits on the check-back date, over the stage and any hold" do
    applicant = applicant_at('on_hold', round: round)
    staff.flag_complicated!(applicant, note: 'n', check_back_on: Date.new(2026, 11, 20))
    expect(applicant.next_step).to have_attributes(owner: :date, due_at: Time.zone.local(2026, 11, 20),
                                                   description: 'Staff to check back on this case')
  end

  it 'restarts the clock when the stage changes' do
    applicant = applicant_at('invited', round: round)
    Timecop.freeze(entered + 3.days) { applicant_changes.advance!(applicant, to: 'applied') }
    expect(applicant.next_step).to have_attributes(owner: :staff, due_at: entered + 10.days)
  end

  (Admissions::Stages::TERMINAL).each do |stage|
    it "#{stage} has no next step" do
      expect(step_at(stage)).to be_nil
    end
  end

  it 'gives every non-terminal state an owner' do
    (Admissions::Stages::ALL - Admissions::Stages::TERMINAL).each do |stage|
      expect(step_at(stage).owner).to be_in(%i[applicant staff date]), stage
    end
  end
end
