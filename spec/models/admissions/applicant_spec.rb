require 'rails_helper'

RSpec.describe Admissions::Applicant do
  let(:applicant) { create_applicant(stage: 'applied') }

  it 'refuses state and contact changes made outside Admissions::ApplicantChanges' do
    {
      email: 'other@example.org', phone: '+44 20 7946 0001', name: 'Someone Else',
      stage: 'confirmed', stage_entered_at: 1.day.ago, held_from_stage: 'eoi', hold_reason: 'x',
      hold_until: Date.current + 1, exited_from_stage: 'eoi', complicated: true, complicated_note: 'x',
      complicated_check_back_on: Date.current
    }.each do |field, value|
      fresh = described_class.find(applicant.id)
      fresh.public_send("#{field}=", value)
      expect(fresh).not_to be_valid, "#{field} changed outside the service"
      expect(fresh.errors[:base]).to include(
        'Applicant state and contact details change only through Admissions::ApplicantChanges'
      )
    end
    expect(Admissions::StateRebuilder).to be_consistent(applicant)
  end

  describe 'database guards' do
    let!(:rows) { described_class.where(id: applicant.id) }

    it 'refuses writes to state or contact details that bypass validation' do
      expect_refused { rows.update_all(stage: 'confirmed') }
      expect_refused { rows.update_all(email: 'other@example.org') }
      expect_refused { applicant.update_columns(stage: 'confirmed') }
      expect_refused { applicant.update_column(:name, 'Someone Else') }
      expect_refused do
        applicant.reload.stage = 'confirmed'
        applicant.save(validate: false)
      end
      expect(applicant.reload.stage).to eq 'applied'
    end

    it 'refuses inserts that bypass the service' do
      expect_refused do
        described_class.new(round: applicant.round, email: 'x@example.org', stage: 'eoi',
                            stage_entered_at: Time.current).save(validate: false)
      end
    end

    it 'never deletes an applicant, even with the service setting on' do
      expect_refused { rows.delete_all }
      expect_refused { applicant.delete }
      expect_refused { with_service_write { rows.delete_all } }
      expect(rows).to exist
    end

    it 'lets other columns through' do
      expect { rows.update_all(updated_at: 1.hour.from_now) }.not_to raise_error
    end

    it 'keeps contact details off a withdrawn stub (check constraint)' do
      withdrawn = applicant_at('withdrawn')
      expect(withdrawn.update(email: 'back@example.org')).to be false
      expect_refused do
        with_service_write { described_class.where(id: withdrawn.id).update_all(email: 'back@example.org') }
      end
      expect_refused do
        with_service_write { rows.update_all(stage: 'withdrawn') }
      end
      expect(withdrawn.reload.email).to be_nil
    end
  end

  it "lists the person's records in every round, oldest first, from any of them" do
    first = create_applicant(round: Fabricate(:admissions_round))
    second = create_applicant(round: Fabricate(:admissions_round), previous_applicant: first)
    third = create_applicant(round: Fabricate(:admissions_round), previous_applicant: second)
    [first, second, third].each { |record| expect(record.person_records).to eq [first, second, third] }
    expect(applicant.person_records).to eq [applicant]
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
