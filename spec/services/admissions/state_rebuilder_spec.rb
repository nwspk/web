require 'rails_helper'

RSpec.describe Admissions::StateRebuilder do
  let(:staff) { staff_changes }

  it 'rebuilds an applicant from its events alone' do
    applicant = create_applicant
    staff.advance!(applicant, to: 'invited')
    staff.hold!(applicant, until_date: Date.current + 9, reason: 'Exams')
    staff.flag_complicated!(applicant, note: 'Unclear', check_back_on: Date.current + 2)

    rebuilt = described_class.rebuild(applicant)
    expect(rebuilt).to eq(
      stage: 'on_hold', stage_entered_at: applicant.events.find_by(kind: 'held').created_at,
      held_from_stage: 'invited', hold_reason: 'Exams', hold_until: Date.current + 9, exited_from_stage: nil,
      complicated: true, complicated_note: 'Unclear', complicated_check_back_on: Date.current + 2
    )
    expect(described_class).to be_consistent(applicant)
  end

  it 'finds a row changed behind the log' do
    applicant = create_applicant
    good = create_applicant
    # Only someone deliberately bypassing the service can do this now.
    with_service_write { Admissions::Applicant.where(id: applicant.id).update_all(stage: 'confirmed') }

    expect(described_class.discrepancies(applicant)).to eq(stage: { cached: 'confirmed', rebuilt: 'eoi' })
    expect(described_class).not_to be_consistent(applicant)
    expect(described_class.inconsistent).to eq [applicant]
    expect(described_class).to be_consistent(good)
  end

  it 'reads the stored row, not unsaved changes in memory' do
    applicant = create_applicant
    applicant.stage = 'confirmed'
    expect(described_class).to be_consistent(applicant)
  end

  it 'agrees with the cached columns after a long random history' do
    rng = Random.new(20_261_002)
    applicants = Array.new(6) { create_applicant(stage: Admissions::Stages::FUNNEL.sample(random: rng)) }
    actions = %i[advance hold return move exit reopen flag clear note]

    300.times do
      applicant = applicants.sample(random: rng).reload
      action = actions.sample(random: rng)
      begin
        case action
        when :advance
          to = Admissions::Stages::TRANSITIONS.keys.select { |from, _| from == applicant.stage }.map(&:last)
                                              .sample(random: rng)
          staff.advance!(applicant, to: to) if to
        when :hold then staff.hold!(applicant, until_date: Date.current + rng.rand(1..60), reason: 'r')
        when :return then staff.return_from_hold!(applicant)
        when :move then staff.move!(applicant, to: Admissions::Stages::FUNNEL.sample(random: rng))
        when :exit then staff.exit!(applicant, to: %w[deferred declined rejected].sample(random: rng))
        when :reopen then staff.reopen!(applicant)
        when :flag then staff.flag_complicated!(applicant, note: 'n', check_back_on: Date.current + rng.rand(0..9))
        when :clear then staff.clear_complicated!(applicant)
        when :note then staff.add_note!(applicant, body: 'n')
        end
      rescue Admissions::ApplicantChanges::IllegalChange
        next
      end
      Timecop.travel(rng.rand(1..90).minutes.from_now)
    end
    Timecop.return

    expect(applicants.sum { |a| a.events.count }).to be > 150
    expect(described_class.inconsistent).to eq []
  end
end
