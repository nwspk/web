module AdmissionsHelper
  # Why the eoi-form is closed, as the staff screens say it.
  EOI_FORM_CLOSED_REASONS = {
    no_privacy_notice: 'no privacy notice has been set (an admissions lead sets it under EOI form wording)',
    no_open_round: 'there is no open round (every round has closed, or there are none)'
  }.freeze

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

  def admissions_autolink(line)
    parts = line.split(%r{(https?://[^\s<>"]+[^\s<>".,;:!?)\]'])})
    safe_join(parts.each_with_index.map { |part, i| i.odd? ? link_to(part, part) : part })
  end
end
