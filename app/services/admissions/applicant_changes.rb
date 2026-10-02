module Admissions
  # The one way an applicant's state changes (SPEC §1, §3, §3a). Each method
  # checks the change is legal and that the actor may make it, then writes
  # the event and updates the applicant's cached columns in one transaction.
  #
  #   changes = Admissions::ApplicantChanges.new(Admissions::Actor.staff(user))
  #   changes.advance!(applicant, to: 'task_sent')
  #
  # Raises IllegalChange for a move the stage machine does not allow,
  # NotPermitted when this actor may not make it, and
  # ActiveRecord::RecordInvalid for bad input (including an email already
  # taken in the round, even when two requests race).
  #
  # Each method works on a freshly locked copy of the applicant, so a stale
  # or dirty object passed in is never trusted; on success the object passed
  # in is reloaded, and on failure it is left exactly as it was.
  class ApplicantChanges
    class IllegalChange < StandardError; end
    class NotPermitted < StandardError; end

    # What a move-to-any-stage would do, shown to staff before it applies.
    # `emails` lists the emails the move would trigger, each to be ticked or
    # not (SPEC §3a); email-sender (phase 1) fills it in. Until then a move
    # triggers no email.
    MovePreview = Struct.new(:from, :to, :emails, keyword_init: true)

    attr_reader :actor

    def initialize(actor)
      @actor = actor
      validate_actor!
    end

    # A new applicant: from the EOI form (the applicant, at `eoi`), or a card
    # created by hand by staff at any funnel stage.
    def create!(round:, email:, phone: nil, name: nil, stage: 'eoi', previous_applicant: nil)
      raise IllegalChange, "cannot create an applicant at #{stage}" unless Stages::FUNNEL.include?(stage)

      permit!(stage == 'eoi' ? %w[applicant staff] : %w[staff], "create an applicant at #{stage}")
      raise NotPermitted, 'an applicant acts only on their own record' if actor.applicant? && actor.applicant_id

      applicant = Applicant.new(round: round, email: email, phone: phone, name: name,
                                previous_applicant: previous_applicant)
      service_write(applicant) do
        now = timestamp
        applicant.assign_attributes(stage: stage, stage_entered_at: now)
        applicant.save!
        log!(applicant, 'created', now, to: stage)
      end
      applicant
    end

    # One step along the funnel (Stages::TRANSITIONS).
    def advance!(applicant, to:)
      change!(applicant) do |applicant, now|
        from = applicant.stage
        raise IllegalChange, 'return the applicant from hold first' if applicant.on_hold?
        raise IllegalChange, "#{from} → #{to} is not a legal transition" unless Stages.transition?(from, to)

        permit!(Stages.transition_actors(from, to), "move #{from} → #{to}")
        applicant.assign_attributes(stage: to, stage_entered_at: now)
        log!(applicant, 'advanced', now, from: from, to: to)
      end
    end

    # On hold until a date, with a reason; returning goes back to the stage
    # the applicant was held from.
    def hold!(applicant, until_date:, reason:)
      change!(applicant) do |applicant, now|
        from = applicant.stage
        raise IllegalChange, "cannot hold an applicant at #{from}" unless Stages.holdable?(from)

        permit!(Stages::HOLD_ACTORS, 'put an applicant on hold')
        require_text!(reason, 'a hold needs a reason')
        unless until_date.is_a?(Date) && until_date > Date.current
          raise IllegalChange, 'a hold needs a return date after today'
        end

        applicant.assign_attributes(stage: Stages::ON_HOLD, stage_entered_at: now, held_from_stage: from,
                                    hold_until: until_date, hold_reason: reason)
        log!(applicant, 'held', now, from: from, to: Stages::ON_HOLD,
                                     details: { 'hold_until' => until_date.iso8601 }, body: reason)
      end
    end

    def return_from_hold!(applicant)
      change!(applicant) do |applicant, now|
        raise IllegalChange, 'the applicant is not on hold' unless applicant.on_hold?

        permit!(Stages::RETURN_ACTORS, 'return an applicant from hold')
        to = applicant.held_from_stage
        applicant.assign_attributes(stage: to, stage_entered_at: now, **cleared_hold)
        log!(applicant, 'returned_from_hold', now, from: Stages::ON_HOLD, to: to)
      end
    end

    def preview_move(applicant, to:)
      MovePreview.new(from: applicant.stage, to: to, emails: [])
    end

    # Staff move to any funnel stage — forwards, backwards or past stages —
    # to fast-track or correct (SPEC §3a). Ends any hold. `emails` are the
    # keys ticked in preview_move's list.
    def move!(applicant, to:, emails: [], note: nil)
      change!(applicant) do |applicant, now|
        from = applicant.stage
        permit!(Stages::MOVE_ACTORS, 'move an applicant to any stage')
        raise IllegalChange, 'a withdrawn applicant cannot be moved' if applicant.withdrawn?
        raise IllegalChange, "cannot move to #{to}: moves go to a funnel stage" unless Stages::FUNNEL.include?(to)
        raise IllegalChange, "the applicant is already at #{to}" if from == to

        offered = preview_move(applicant, to: to).emails.pluck(:key)
        unknown = emails - offered
        raise IllegalChange, "the move would not send #{unknown.join(', ')}" if unknown.any?

        applicant.assign_attributes(stage: to, stage_entered_at: now, exited_from_stage: nil, **cleared_hold)
        log!(applicant, 'moved', now, from: from, to: to, details: { 'emails' => emails }, body: note.presence)
      end
    end

    # Leave the funnel. `deferred` is "not this year": the record is kept and
    # reminded when the next round opens. `withdrawn` is "remove my details":
    # personal data is scrubbed, keeping an anonymised stub (SPEC §3, §9b).
    # Dropping out is not withdrawing. Any exit clears "it's complicated",
    # with its own event, so no flagged applicant sits in a terminal stage.
    def exit!(applicant, to:, note: nil)
      change!(applicant) do |applicant, now|
        from = applicant.stage
        raise IllegalChange, "#{to} is not an exit state" unless Stages::EXITS.include?(to)
        raise IllegalChange, "cannot go from #{from} to #{to}" unless Stages.exit_reachable?(from, to)

        permit!(Stages::EXIT_ACTORS.fetch(to), "move an applicant to #{to}")
        resume = Stages.exit?(from) ? applicant.exited_from_stage : applicant.funnel_stage
        if applicant.complicated?
          applicant.assign_attributes(**cleared_complicated)
          log!(applicant, 'cleared_complicated', now)
        end
        applicant.assign_attributes(stage: to, stage_entered_at: now, exited_from_stage: resume, **cleared_hold)
        log!(applicant, 'exited', now, from: from, to: to, details: { 'resume_stage' => resume }, body: note.presence)
        scrub!(applicant, now) if to == 'withdrawn'
      end
    end

    def withdraw!(applicant)
      exit!(applicant, to: 'withdrawn')
    end

    # A deferred applicant comes back to the stage they deferred from. The
    # applicant can do this only while the round is open; staff can always.
    def reopen!(applicant)
      change!(applicant) do |applicant, now|
        raise IllegalChange, 'only a deferred applicant can be reopened' unless applicant.stage == 'deferred'

        permit!(Stages::REOPEN_ACTORS, 'reopen a deferred applicant')
        raise NotPermitted, 'the round has closed' if actor.applicant? && applicant.round.closed?

        to = applicant.exited_from_stage
        raise IllegalChange, 'no stage to reopen to' if to.blank?

        applicant.assign_attributes(stage: to, stage_entered_at: now, exited_from_stage: nil)
        log!(applicant, 'reopened', now, from: 'deferred', to: to)
      end
    end

    # "It's complicated" is a flag, not a stage: the applicant keeps their
    # stage (and hold); the flag needs a note and a check-back date.
    def flag_complicated!(applicant, note:, check_back_on:)
      change!(applicant) do |applicant, now|
        permit!(Stages::FLAG_ACTORS, "flag an applicant \"it's complicated\"")
        raise IllegalChange, "cannot flag an applicant at #{applicant.stage}" if Stages.exit?(applicant.stage)

        require_text!(note, "\"it's complicated\" needs a note")
        unless check_back_on.is_a?(Date) && check_back_on >= Date.current
          raise IllegalChange, "\"it's complicated\" needs a check-back date, today or later"
        end

        applicant.assign_attributes(complicated: true, complicated_note: note, complicated_check_back_on: check_back_on)
        log!(applicant, 'flagged_complicated', now, details: { 'check_back_on' => check_back_on.iso8601 }, body: note)
      end
    end

    def clear_complicated!(applicant)
      change!(applicant) do |applicant, now|
        permit!(Stages::FLAG_ACTORS, "clear \"it's complicated\"")
        raise IllegalChange, "the applicant is not flagged \"it's complicated\"" unless applicant.complicated?

        applicant.assign_attributes(**cleared_complicated)
        log!(applicant, 'cleared_complicated', now)
      end
    end

    def add_note!(applicant, body:)
      change!(applicant) do |applicant, now|
        permit!(Stages::NOTE_ACTORS, 'add a note')
        raise IllegalChange, 'a withdrawn applicant takes no notes' if applicant.withdrawn?

        require_text!(body, 'a note needs text')
        log!(applicant, 'note_added', now, body: body)
      end
    end

    # Correct email, phone or name. The event names the fields changed, not
    # their values, so the log holds no contact details.
    def update_details!(applicant, **attrs)
      unknown = attrs.keys - Applicant::PERSONAL_FIELDS
      raise ArgumentError, "not a contact field: #{unknown.join(', ')}" if unknown.any?

      change!(applicant) do |applicant, now|
        permit!(Stages::DETAILS_ACTORS, 'change contact details')
        raise IllegalChange, 'a withdrawn applicant has no details' if applicant.withdrawn?

        applicant.assign_attributes(attrs)
        fields = applicant.changed & attrs.keys.map(&:to_s)
        log!(applicant, 'details_changed', now, details: { 'fields' => fields }) if fields.any?
      end
    end

    private

    def validate_actor!
      unless actor.is_a?(Actor) && Stages::ACTOR_TYPES.include?(actor.type)
        raise ArgumentError, "unknown actor #{actor.inspect}"
      end
      raise ArgumentError, 'only a staff actor names a user' if !actor.staff? && actor.user
      raise ArgumentError, 'only an applicant actor names an applicant' if !actor.applicant? && actor.applicant_id
      return unless actor.staff?

      return if actor.user && Ability.new(actor.user).can?(:update, Applicant)

      raise NotPermitted, 'only admissions staff can act as staff'
    end

    def permit!(actor_types, what)
      raise NotPermitted, "#{actor} may not #{what}" unless actor_types.include?(actor.type)
    end

    def require_text!(text, message)
      raise IllegalChange, message if text.blank?
    end

    # Locks a fresh copy of the row, lets the block assign the new state and
    # log its event, then saves — all in one transaction. The caller's object
    # is reloaded once the change has committed.
    def change!(applicant)
      if actor.applicant? && actor.applicant_id != applicant.id
        raise NotPermitted, 'an applicant acts only on their own record'
      end

      fresh = nil
      service_write(applicant) do
        fresh = Applicant.lock.find(applicant.id)
        yield fresh, timestamp
        fresh.save!
      end
      applicant.reload
    end

    # The one transaction every write runs in. Inside it, and only inside it,
    # admissions.service_write is on, which the applicant validation and the
    # database trigger both require. A savepoint (requires_new) means a
    # failed change rolls the setting back with everything else.
    def service_write(record)
      Applicant.transaction(requires_new: true) do
        allow_service_write('on')
        yield
        allow_service_write('off')
      end
    rescue ActiveRecord::RecordNotUnique
      record.errors.add(:email, :taken)
      raise ActiveRecord::RecordInvalid, record
    end

    def allow_service_write(value)
      Applicant.connection.select_value(
        Applicant.sanitize_sql(["SELECT set_config('admissions.service_write', ?, true)", value])
      )
    end

    def log!(applicant, kind, now, from: nil, to: nil, details: {}, body: nil)
      ApplicantEvent.create!(applicant: applicant, kind: kind, actor_type: actor.type, actor_user: actor.user,
                             from_stage: from, to_stage: to, details: details, body: body, created_at: now)
    end

    # Withdrawal scrubs this round's record only (Ed, 2026-10-02); the links
    # to the person's records in other rounds are kept, so staff can find
    # them all with Applicant#person_records and withdraw each one.
    def scrub!(applicant, now)
      applicant.assign_attributes(Applicant::PERSONAL_FIELDS.index_with(nil))
      ApplicantEvent.redact_bodies_for(applicant, at: now)
    end

    def cleared_hold = { held_from_stage: nil, hold_until: nil, hold_reason: nil }
    def cleared_complicated = { complicated: false, complicated_note: nil, complicated_check_back_on: nil }

    # Microsecond precision, as Postgres stores it, so the cached columns and
    # the event timestamps compare equal before and after a reload.
    def timestamp = Time.current.floor(6)
  end
end
