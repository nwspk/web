require 'rails_helper'

RSpec.describe Admissions::Applicant do
  let(:applicant) { create_applicant(stage: 'applied') }

  it 'refuses state changes made outside Admissions::ApplicantChanges' do
    {
      stage: 'confirmed', stage_entered_at: 1.day.ago, held_from_stage: 'eoi', hold_reason: 'x',
      hold_until: Date.current + 1, exited_from_stage: 'eoi', complicated: true, complicated_note: 'x',
      complicated_check_back_on: Date.current
    }.each do |field, value|
      fresh = described_class.find(applicant.id)
      fresh.public_send("#{field}=", value)
      expect(fresh).not_to be_valid, "#{field} changed outside the service"
      expect(fresh.errors[:stage]).to include('can only change through Admissions::ApplicantChanges')
    end
    expect(Admissions::StateRebuilder).to be_consistent(applicant)
  end

  it 'lets contact details be saved directly' do
    expect(applicant.update(phone: '+44 20 7946 0001')).to be true
  end

  it 'refuses to be created without the service' do
    record = described_class.new(round: Fabricate(:admissions_round), email: 'x@example.org', stage: 'eoi',
                                 stage_entered_at: Time.current)
    expect(record).not_to be_valid
  end

  it 'lists the active (non-terminal) applicants' do
    active = [applicant, applicant_at('on_hold')]
    applicant_at('confirmed')
    applicant_at('rejected')
    expect(described_class.active).to match_array active
  end

  it 'knows its funnel stage while on hold' do
    held = applicant_at('on_hold')
    expect(held.funnel_stage).to eq 'applied'
    expect(applicant.funnel_stage).to eq 'applied'
  end
end
