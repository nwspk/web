module Admissions
  # Applicant actions staff take from the admissions screens. For now, the
  # pause switch for automatic email (SPEC §3a "Upcoming emails"); the
  # applicant's card comes in a later phase.
  class ApplicantsController < BaseController
    before_action :load_applicant

    def pause_emails
      changes.pause_emails!(@applicant)
      redirect_back_or_to admissions_emails_path, notice: "Automatic email to #{who} is paused."
    end

    def resume_emails
      changes.resume_emails!(@applicant)
      redirect_back_or_to admissions_emails_path, notice: "Automatic email to #{who} is back on."
    end

    rescue_from ApplicantChanges::IllegalChange do |e|
      redirect_back_or_to admissions_emails_path, alert: "Nothing done: #{e.message}."
    end

    private

    def load_applicant
      @applicant = Applicant.find(params[:id])
      authorize! :update, @applicant
    end

    def changes
      ApplicantChanges.new(Actor.staff(current_user))
    end

    def who
      @applicant.name.presence || @applicant.email
    end
  end
end
