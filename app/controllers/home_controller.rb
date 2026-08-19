class HomeController < ApplicationController
  layout :resolve_layout

  # The feedback page presents the feedback Google Form's questions natively
  # (the form itself can't be styled). Submissions are relayed server-side to
  # the form's formResponse endpoint, so responses land in the same
  # spreadsheet as before. The entry.* names are the Google Form's internal
  # field IDs: if the Google Form is edited, re-derive them from
  # FB_PUBLIC_LOAD_DATA_ in the viewform page source, update here and in the
  # view, and make a test submission.
  FEEDBACK_FORM_ID = '1FAIpQLSfMqX_Ry3beaB0-9XsJWNBpssTvkQiIGtWfbWnHzAeAMGj_jA'.freeze
  FEEDBACK_FIELDS = {
    name: 'entry.715514050',
    contact: 'entry.503492203',
    feedback: 'entry.2137140456'
  }.freeze
  FEEDBACK_INCIDENT_FIELD = 'entry.48862705'.freeze

  def index
    @events  = Event.public_and_confirmed.upcoming
    @fellows = User.fellows
    @past_events = Event.public_and_confirmed.archive
  end

  def fellowship
    # Static register loaded from config/fellows.yml (see lib/tasks / tmp scripts
    # that generate it from the CSV register + scraped photos). Pre-sorted
    # latest-cohort-first; group_by preserves that order.
    fellows = YAML.load_file(Rails.root.join('config', 'fellows.yml'))
    @cohorts = fellows.group_by { |f| f['cohort'] }
  end

  def residency
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def study_with_us
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def course2023
    @fellows = User.fellows
    @alumni  = User.alumni
  end

  def residents
    @fellows = User.fellows
  end

  def submit_feedback
    answers  = FEEDBACK_FIELDS.keys.index_with { |key| params[key].to_s.strip }
    incident = params[:incident].to_s.strip
    # Browsers enforce `required`; anything arriving blank is not a real
    # submission, so drop it rather than relay junk or email noise.
    return redirect_to feedback_path if answers.value?('')

    fields = FEEDBACK_FIELDS.to_h { |key, entry| [entry, answers[key]] }
                            .merge(GoogleFormRelay.date_time_fields(FEEDBACK_INCIDENT_FIELD, incident))

    if GoogleFormRelay.submit(FEEDBACK_FORM_ID, fields)
      redirect_to feedback_path(sent: 'recorded')
    else
      # Google didn't confirm (stale field mapping, outage, timeout) — the
      # submission would otherwise vanish, so capture it by email instead and
      # tell the submitter that's what happened.
      AdminMailer.feedback_fallback_email(
        answers[:name], answers[:contact], incident, answers[:feedback]
      ).deliver_later
      redirect_to feedback_path(sent: 'emailed')
    end
  end

  private

  def resolve_layout
    action_name == 'index' ? 'home' : 'subpage'
  end
end
