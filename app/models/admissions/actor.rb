module Admissions
  # Who did something to an applicant: a staff user, the applicant, or the
  # system. Every ApplicantEvent records one. An applicant actor names the
  # applicant record it is (nil only while submitting a new EOI), and may act
  # on that record alone.
  Actor = Struct.new(:type, :user, :applicant_id) do
    def self.staff(user) = new('staff', user, nil)
    def self.applicant(applicant = nil) = new('applicant', nil, applicant.is_a?(Applicant) ? applicant.id : applicant)
    def self.system = new('system', nil, nil)

    def staff? = type == 'staff'
    def applicant? = type == 'applicant'
    def system? = type == 'system'

    def to_s
      case type
      when 'staff' then "staff user ##{user&.id}"
      when 'applicant' then "applicant ##{applicant_id || 'new'}"
      else type
      end
    end
  end
end
