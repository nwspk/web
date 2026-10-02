module AdmissionsHelpers
  def admissions_staff(role: 'lead', user: Fabricate(:user))
    Fabricate(:admissions_staff_member, user: user, role: role).user
  end

  def staff_changes(user = admissions_staff)
    Admissions::ApplicantChanges.new(Admissions::Actor.staff(user))
  end

  def applicant_changes = Admissions::ApplicantChanges.new(Admissions::Actor.applicant)
  def system_changes = Admissions::ApplicantChanges.new(Admissions::Actor.system)

  # A new applicant, created by hand by staff at `stage`.
  def create_applicant(stage: 'eoi', round: Fabricate(:admissions_round), by: staff_changes, **attrs)
    by.create!(round: round, email: Faker::Internet.email, phone: Faker::PhoneNumber.phone_number,
               name: Faker::Name.name, stage: stage, **attrs)
  end
end

RSpec.configure { |config| config.include AdmissionsHelpers }
