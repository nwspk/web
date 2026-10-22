class Ability
  include CanCan::Ability

  ADMISSIONS_MODELS = [
    Admissions::Round, Admissions::Applicant, Admissions::ApplicantEvent, Admissions::StaffMember,
    Admissions::EmailTemplate, Admissions::Email, Admissions::FormText
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
  # also hold one. Leads also manage rounds, their email templates, the
  # eoi-form's wording and the staff list. Any staff member may work the approval queue (SPEC §9b: it
  # is shared). Nobody may change or delete the event log, or delete an
  # email.
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
      can :read, Admissions::ApplicantEvent # written only by the admissions services
      can :read, Admissions::StaffMember
      can :read, Admissions::EmailTemplate
      can %i[read update], Admissions::Email # written only by Admissions::EmailSender
      can :read, Admissions::FormText
      if staff.lead?
        can :manage, [Admissions::Round, Admissions::StaffMember, Admissions::EmailTemplate]
        can %i[read create], Admissions::FormText # each edit is a new version
      else
        # Withdrawal erases a person's details and can't be undone, so it
        # is a lead's act; every other card action is shared.
        cannot :withdraw, Admissions::Applicant
      end
    end

    cannot %i[update destroy], Admissions::ApplicantEvent
    cannot :destroy, [Admissions::Applicant, Admissions::Email, Admissions::EmailTemplate]
  end
end
