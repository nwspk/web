require 'rails_helper'

RSpec.describe Ability, 'admissions' do
  let(:applicant) { create_applicant }
  let(:event) { applicant.events.first }
  let(:models) { [Admissions::Round, Admissions::Applicant, Admissions::ApplicantEvent, Admissions::StaffMember] }

  it 'gives a site admin without an admissions role only the staff list, and everything else as before' do
    ability = described_class.new(Fabricate(:user, role: 'admin'))
    (models - [Admissions::StaffMember]).each { |model| expect(ability.can?(:read, model)).to be(false), model.name }
    expect(ability.can?(:manage, Admissions::StaffMember)).to be true
    expect(ability.can?(:read, applicant)).to be false
    expect(ability.can?(:manage, :all)).to be true
    expect(ability.can?(:manage, User)).to be true
    expect(ability.can?(:manage, Event)).to be true
  end

  it 'gives site staff, members and visitors no admissions access' do
    [Fabricate(:user, role: 'staff'), Fabricate(:user), nil].each do |user|
      ability = described_class.new(user)
      models.each { |model| expect(ability.can?(:read, model)).to be false }
    end
  end

  it 'lets an officer work applicants and read the log, but not run rounds or staff' do
    ability = described_class.new(admissions_staff(role: 'officer'))
    expect(ability.can?(:update, applicant)).to be true
    expect(ability.can?(:read, event)).to be true
    expect(ability.can?(:read, Admissions::Round)).to be true
    expect(ability.can?(:update, Admissions::Round)).to be false
    expect(ability.can?(:create, Admissions::StaffMember)).to be false
  end

  it 'lets a lead also run rounds and the staff list' do
    ability = described_class.new(admissions_staff(role: 'lead'))
    expect(ability.can?(:update, applicant)).to be true
    expect(ability.can?(:create, Admissions::Round)).to be true
    expect(ability.can?(:create, Admissions::StaffMember)).to be true
  end

  it 'lets nobody write the log directly, change or delete it, or delete an applicant' do
    user = Fabricate(:user, role: 'admin')
    Fabricate(:admissions_staff_member, user: user, role: 'lead')
    ability = described_class.new(user)
    expect(ability.can?(:update, event)).to be false
    expect(ability.can?(:destroy, event)).to be false
    expect(ability.can?(:destroy, applicant)).to be false
    expect(ability.can?(:create, Admissions::ApplicantEvent)).to be false
  end
end
