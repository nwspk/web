require 'rails_helper'

RSpec.describe Admissions::StaffMember do
  it 'gives a user one admissions role, lead or officer' do
    member = Fabricate(:admissions_staff_member, role: 'officer')
    expect(member).to be_officer
    expect(Fabricate.build(:admissions_staff_member, user: member.user)).not_to be_valid
    expect(Fabricate.build(:admissions_staff_member, role: 'admin')).not_to be_valid
  end

  it 'leaves the site role alone' do
    member = Fabricate(:admissions_staff_member, user: Fabricate(:user, role: 'fellow'))
    expect(member.user.reload.role).to eq 'fellow'
  end

  it 'finds the membership for a user, if any' do
    member = Fabricate(:admissions_staff_member)
    expect(described_class.for(member.user)).to eq member
    expect(described_class.for(Fabricate(:user))).to be_nil
    expect(described_class.for(User.new)).to be_nil
    expect(described_class.for(nil)).to be_nil
  end

  it 'goes when the user is deleted' do
    member = Fabricate(:admissions_staff_member)
    member.user.destroy
    expect(described_class.where(id: member.id)).not_to exist
  end
end
