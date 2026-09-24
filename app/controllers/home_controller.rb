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

  # Bot traps. Spam began when the form became native: generic form-fillers
  # can't see into Google's iframe, but they can see a plain form on our page,
  # and the CSRF token is no obstacle to anything that loads the page first.
  # The honeypot is a field people never see, so only a bot fills it. The time
  # trap is the signed moment the form was served: nobody completes three
  # required fields within seconds of that. This form takes reports against
  # individuals, so the traps are built never to catch a person — a missing
  # stamp (form open across a deploy) passes; only a forged or too-fresh one
  # is caught.
  FEEDBACK_HONEYPOT = :subject
  FEEDBACK_MIN_FILL_TIME = 3.seconds

  def index
    @events = Event.public_and_confirmed.upcoming
  end

  def fellowship
    # Static register loaded from config/fellows.yml, which is edited by hand
    # (it was first built from the CSV register + scraped photos; that script
    # was never committed). Pre-sorted latest-cohort-first; group_by preserves
    # that order.
    fellows = YAML.load_file(Rails.root.join('config', 'fellows.yml'))
    @cohorts = fellows.group_by { |f| f['cohort'] }
  end

  def residency
    @alumni = User.alumni
  end

  def study_with_us; end

  def course2023
    @fellows = User.fellows
  end

  def residents
    @fellows = User.fellows
  end

  def feedback
    @served_at = feedback_stamp_verifier.generate(Time.current.to_i)
  end

  def submit_feedback
    if (trap = sprung_feedback_trap)
      # Answer exactly as a success would, so a bot learns nothing. The log
      # line records only that a trap fired: production logs through lograge,
      # which keeps no request parameters, so what was sent is not retained.
      logger.warn("Feedback #{trap} sprung by #{request.remote_ip}; submission not relayed")
      return redirect_to feedback_path(sent: 'recorded')
    end

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

  def feedback_stamp_verifier
    Rails.application.message_verifier(:feedback_served_at)
  end

  # Names the trap a submission fell into, or nil for one that looks human.
  def sprung_feedback_trap
    return 'honeypot' if params[FEEDBACK_HONEYPOT].present?
    return if params[:served_at].blank?

    served_at = feedback_stamp_verifier.verified(params[:served_at])
    'time trap' if served_at.nil? || Time.current.to_i - served_at < FEEDBACK_MIN_FILL_TIME
  end

  def resolve_layout
    action_name == 'index' ? 'home' : 'subpage'
  end
end
