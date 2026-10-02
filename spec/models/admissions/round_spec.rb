require 'rails_helper'

RSpec.describe Admissions::Round do
  it 'needs a unique name' do
    Fabricate(:admissions_round, name: 'Fellowship 2027')
    expect(Fabricate.build(:admissions_round, name: 'Fellowship 2027')).not_to be_valid
    expect(Fabricate.build(:admissions_round, name: '')).not_to be_valid
  end

  it 'needs its dates in order, allowing gaps' do
    expect(Fabricate.build(:admissions_round, opens_on: Date.new(2027, 3, 1))).not_to be_valid
    expect(Fabricate.build(:admissions_round, invites_on: nil, closes_on: nil)).to be_valid
  end

  it 'has applications open from the invitation date until it is closed' do
    round = Fabricate(:admissions_round, invites_on: Date.new(2027, 2, 1))
    expect(round.applications_open?(on: Date.new(2027, 1, 31))).to be false
    expect(round.applications_open?(on: Date.new(2027, 2, 1))).to be true
    round.update!(closed_at: Time.current)
    expect(round).to be_closed
    expect(round.applications_open?(on: Date.new(2027, 2, 1))).to be false
  end

  it 'cannot be deleted while it has applicants' do
    round = Fabricate(:admissions_round)
    create_applicant(round: round)
    expect { round.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end
