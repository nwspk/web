module Admissions
  # Who did something to an applicant: a staff user, the applicant, or the
  # system. Every ApplicantEvent records one.
  Actor = Struct.new(:type, :user) do
    def self.staff(user) = new('staff', user)
    def self.applicant = new('applicant', nil)
    def self.system = new('system', nil)

    def staff? = type == 'staff'
    def applicant? = type == 'applicant'
    def system? = type == 'system'

    def to_s
      staff? ? "staff user ##{user&.id}" : type
    end
  end
end
