module AdmissionsHelper
  # Why the eoi-form is closed, as the staff screens say it.
  EOI_FORM_CLOSED_REASONS = {
    no_privacy_notice: 'no privacy notice has been set (an admissions lead sets it under EOI form wording)',
    no_open_round: 'there is no open round (every round has closed, or there are none)'
  }.freeze

  # Why an automatic email was skipped (email_skipped), in plain words.
  EMAIL_SKIPPED_REASONS = {
    'withdrawn' => 'the applicant has withdrawn',
    'complicated' => "the applicant is flagged \"it's complicated\", so gets no automatic email",
    'paused' => 'automatic email to this applicant is paused',
    'off' => "this email's mode is Off in the round's settings"
  }.freeze

  # Why an automatic email couldn't be drafted (email_not_drafted).
  EMAIL_NOT_DRAFTED_REASONS = {
    'missing_template' => 'the round has no template for it',
    'placeholder_unfilled' => "its template uses a placeholder this applicant can't fill"
  }.freeze

  # Why nothing automatic is being drafted for an applicant just now
  # (UpcomingEmails.suppressed_because).
  EMAIL_SUPPRESSED = {
    withdrawn: 'This applicant has withdrawn, so gets no email.',
    complicated: "This applicant is flagged \"it's complicated\", so no automatic email is drafted for them.",
    paused: 'Automatic email to this applicant is paused, so none is drafted.'
  }.freeze

  def admissions_stage_label(stage) = Admissions::Stages.label(stage)

  # "12 days", "about 2 months": how long the applicant has sat in their
  # stage (or on hold, or since withdrawing).
  def admissions_time_in_stage(applicant)
    time_ago_in_words(applicant.stage_entered_at)
  end

  # One line saying what an event was, in plain words; its body (a note, a
  # reason, an email's text) is shown separately.
  def admissions_event_summary(event)
    details = event.details
    type = details['email_type'] && Admissions::EmailTypes::TYPES.fetch(details['email_type'], details['email_type'])
    from = event.from_stage && admissions_stage_label(event.from_stage)
    to = event.to_stage && admissions_stage_label(event.to_stage)

    case event.kind
    when 'created' then admissions_created_summary(event, to)
    when 'advanced' then "Moved on from #{from} to #{to}"
    when 'held' then "Put on hold until #{admissions_date(details['hold_until'])}, from #{from}"
    when 'returned_from_hold' then "Returned from hold to #{to}"
    when 'moved' then "Moved from #{from} to #{to}. The move sent no email."
    when 'exited'
      event.to_stage == 'withdrawn' ? "Withdrawn from #{from}: personal details removed" : "#{to}, from #{from}"
    when 'reopened' then "Reopened from Deferred to #{to}"
    when 'flagged_complicated'
      "Flagged \"it's complicated\", to check back on #{admissions_date(details['check_back_on'])}"
    when 'cleared_complicated' then "\"It's complicated\" cleared"
    when 'note_added' then 'Note'
    when 'details_changed' then "Contact details changed: #{Array(details['fields']).to_sentence}"
    when 'eoi_repeated'
      'Sent the EOI form again with the same address. Nothing changed and no email was sent' \
        "#{details['new_phone'] ? '; they gave a different phone number' : ''}."
    when 'emails_paused' then 'Automatic email paused'
    when 'emails_resumed' then 'Automatic email resumed'
    else admissions_email_event_summary(event, type)
    end
  end

  # How staff screens name whoever acted.
  def admissions_actor_name(actor)
    return 'nobody' unless actor

    case actor.type
    when 'staff' then actor.user&.name || 'a staff member'
    when 'applicant' then 'the applicant'
    else 'the system'
    end
  end

  # Wording staff wrote as plain text (the eoi-form's introduction and
  # privacy notice): a blank line starts a paragraph, a line break is kept,
  # and web addresses become links. Everything else is escaped, so nothing
  # typed there can add markup to the page.
  def admissions_wording(text)
    paragraphs = text.to_s.strip.split(/\n\s*\n/).map do |para|
      lines = para.strip.split("\n").map { |line| admissions_autolink(line) }
      tag.p(safe_join(lines, tag.br))
    end
    safe_join(paragraphs)
  end

  private

  def admissions_created_summary(event, to)
    case event.details['via']
    when 'eoi_form'
      "Expressed interest through the EOI form (privacy notice version #{event.details['privacy_notice_version']})"
    when 'by_hand'
      given = event.details['first_interest_on']
      "Card created by hand at #{to}#{given ? ", first expressed interest #{admissions_date(given)}" : ''}"
    else
      "Card created at #{to}"
    end
  end

  def admissions_email_event_summary(event, type)
    details = event.details
    case event.kind
    when 'email_drafted'
      mode = details['mode'] && Admissions::EmailTypes::MODES.fetch(details['mode'], details['mode'])
      mode ? "#{type} drafted (its mode: #{mode})" : "#{type} drafted, to send now"
    when 'email_not_drafted'
      "#{type} not drafted: #{EMAIL_NOT_DRAFTED_REASONS.fetch(details['reason'], details['reason'])}"
    when 'email_skipped'
      "#{type} skipped: #{EMAIL_SKIPPED_REASONS.fetch(details['reason'], details['reason'])}"
    when 'email_edited' then "#{type} edited"
    when 'email_discarded'
      "#{type} discarded#{details['reason'] == 'withdrawn' ? ', because the applicant withdrew' : ''}"
    when 'email_sending' then "#{type}: sending began"
    when 'email_sent' then "#{type} sent#{admissions_sent_how(details)}"
    when 'email_send_failed' then "#{type} not sent, and back in the approval queue: #{details['error']}"
    when 'email_outcome_unknown' then "#{type}: outcome unknown (#{details['error']})"
    when 'email_returned_to_held' then "#{type}: staff found it wasn't sent; back in the approval queue"
    else event.kind.humanize
    end
  end

  def admissions_sent_how(details)
    if details['confirmed_by_staff']
      ', confirmed by staff from the admissions@ Sent folder'
    elsif details['delivery'] == 'recording'
      ' (recording only: nothing actually went out)'
    else
      ''
    end
  end

  def admissions_date(iso)
    iso && l(Date.iso8601(iso), format: :long)
  end

  def admissions_autolink(line)
    parts = line.split(%r{(https?://[^\s<>"]+[^\s<>".,;:!?)\]'])})
    safe_join(parts.each_with_index.map { |part, i| i.odd? ? link_to(part, part) : part })
  end
end
