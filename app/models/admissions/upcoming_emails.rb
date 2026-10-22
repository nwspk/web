module Admissions
  # What the system is about to send an applicant (SPEC §3a "Upcoming emails
  # on every card"): each item says what, when and why. For now that is
  # every email waiting in the outbox: held for a staff member's approval,
  # being sent, or sent with an outcome nobody knows. reminder-sender
  # (phase 2) adds each applicant's next reminder here, as another Item.
  class UpcomingEmails
    # status: :held, :sending or :outcome_unknown. `at` is when it was
    # drafted or began sending; `email` is the outbox row, when there is one.
    Item = Struct.new(:label, :status, :at, :why, :email, keyword_init: true)

    def self.for(applicant, now: Time.current)
      applicant.emails.where(status: %w[held sending]).map { |email| from_outbox(email, now) }
    end

    def self.from_outbox(email, now)
      if email.held?
        Item.new(label: email.label, status: :held, at: email.drafted_at, email: email,
                 why: email.drafted_by_type == 'system' ? :ask_me_first : :drafted_by_staff)
      else
        Item.new(label: email.label, status: email.outcome_unknown?(now: now) ? :outcome_unknown : :sending,
                 at: email.sending_at, email: email, why: :approved)
      end
    end

    # Why nothing automatic will be drafted for this applicant just now, or
    # nil: the same suppressions EmailSender applies, in the same order.
    def self.suppressed_because(applicant)
      return :withdrawn if applicant.withdrawn?
      return :complicated if applicant.complicated?

      :paused if applicant.emails_paused?
    end
  end
end
