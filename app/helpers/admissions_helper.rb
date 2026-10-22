module AdmissionsHelper
  # How staff screens name whoever acted.
  def admissions_actor_name(actor)
    return 'nobody' unless actor

    case actor.type
    when 'staff' then actor.user&.name || 'a staff member'
    when 'applicant' then 'the applicant'
    else 'the system'
    end
  end
end
