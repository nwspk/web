module Admissions
  # Every applicant not in a terminal state has a next step, an owner and a
  # due time (SPEC §3a "Nobody gets lost"):
  #
  # - waiting on the applicant: due at their next reminder (7 days after the
  #   last contact);
  # - waiting on staff: due after the stage's turnaround target (7 days);
  # - waiting on a date: due on that date — the invitation date for an EOI
  #   before applications open, the return date on hold, the check-back
  #   date while "it's complicated" (which takes precedence over the stage).
  #
  # A nil due_at means the applicant has no due time; the daily check (later)
  # flags those. The reminder interval and the staff turnarounds are the
  # applicant's round settings (7 days unless changed).
  NextStep = Struct.new(:description, :owner, :due_at, keyword_init: true) do

    def self.for(applicant, now: Time.current)
      return nil if applicant.terminal?

      if applicant.complicated?
        return new(description: Stages::NEXT_STEP[:complicated], owner: :date,
                   due_at: start_of(applicant.complicated_check_back_on))
      end
      if applicant.on_hold?
        return new(description: Stages::NEXT_STEP[Stages::ON_HOLD], owner: :date,
                   due_at: start_of(applicant.hold_until))
      end

      stage = applicant.stage
      description = Stages::NEXT_STEP.fetch(stage)
      case Stages::WAITING_ON.fetch(stage)
      when :applicant
        new(description: description, owner: :applicant,
            due_at: applicant.last_contacted_at + applicant.round.reminder_interval)
      when :staff
        staff_step(description, applicant, stage)
      when :date
        date_step(description, applicant, stage, now)
      end
    end

    def self.staff_step(description, applicant, stage)
      new(description: description, owner: :staff,
          due_at: applicant.stage_entered_at + applicant.round.staff_turnaround(stage))
    end

    def self.date_step(description, applicant, stage, now)
      case stage
      when 'eoi'
        round = applicant.round
        if round.applications_open?(on: now.to_date)
          staff_step('Staff to invite', applicant, stage).tap do |step|
            # An EOI that arrived before applications opened is due from the
            # opening date, not from when it arrived.
            opened = start_of(round.invites_on)
            step.due_at = [step.due_at, opened + round.staff_turnaround(stage)].max
          end
        else
          new(description: description, owner: :date, due_at: start_of(round.invites_on))
        end
      when 'interview_booked'
        # The interview time comes from interview-scheduler (phase 3); until
        # then a booked interview has no due time.
        new(description: description, owner: :date, due_at: nil)
      end
    end

    def self.start_of(date)
      date&.in_time_zone&.beginning_of_day
    end
  end
end
