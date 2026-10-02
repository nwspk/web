class Ability
  include CanCan::Ability

  ADMISSIONS_MODELS = [
    Admissions::Round, Admissions::Applicant, Admissions::ApplicantEvent, Admissions::StaffMember
  ].freeze

  def initialize(user)
    user ||= User.new

    if user.admin?
      can :manage, :all
    end

    admissions(user)
  end

  private

  # Admissions access comes only from an admissions staff role (SPEC §9b),
  # never from users.role: a site admin is not admissions staff unless they
  # also hold one. Leads also manage rounds and the staff list. Nobody may
  # change or delete the event log.
  #
  # The one exception: site admins may grant and remove admissions roles
  # (in ActiveAdmin), and nothing else, so the first lead can be made
  # without a console. A site admin controls every account anyway.
  def admissions(user)
    cannot :manage, ADMISSIONS_MODELS
    can :manage, Admissions::StaffMember if user.admin?

    staff = Admissions::StaffMember.for(user)
    if staff
      can :read, Admissions::Round
      can :manage, Admissions::Applicant
      can :read, Admissions::ApplicantEvent # written only by Admissions::ApplicantChanges
      can :read, Admissions::StaffMember
      can :manage, [Admissions::Round, Admissions::StaffMember] if staff.lead?
    end

    cannot %i[update destroy], Admissions::ApplicantEvent
    cannot :destroy, Admissions::Applicant
  end
end
