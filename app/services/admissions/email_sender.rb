module Admissions
  # email-sender (SPEC §2, §3a "Email modes", §4): every admissions email
  # goes through here. It drafts an email from its round's template, holds
  # or sends it, and logs each step on the applicant's event log with the
  # exact text, so the card's correspondence can be built from the log.
  #
  # Two ways in:
  #
  #   # An automatic email, asked for by the system (any later phase):
  #   Admissions::EmailSender.request_automatic!(applicant, 'confirmation')
  #
  #   # An email staff send with a button: the click is the approval.
  #   Admissions::EmailSender.new(Admissions::Actor.staff(user)).send_now!(applicant, 'task')
  #
  # and the approval queue's actions, for staff: edit!, send_held!,
  # discard!, and confirm_sent! / confirm_not_sent! for a send whose
  # outcome is unknown.
  #
  # An automatic email follows its type's mode in the applicant's round:
  # off drafts nothing, ask me first drafts and holds it, automatic drafts
  # and sends it. Whatever the mode, nothing automatic is drafted for an
  # applicant who is withdrawn, flagged "it's complicated", or paused (an
  # email_skipped event says why), nor when the round has no template for
  # the type or a placeholder can't be filled (email_not_drafted). Neither
  # raises, so the action that asked for the email always carries on.
  #
  # Sending is three steps, so that nothing is ever sent twice or lost:
  #
  # 1. the email is marked sending, and that is logged and committed;
  # 2. the mail service is called, outside any transaction, and only once
  #    every transaction open around the caller has committed: an EOI form
  #    that rolls back never emails anyone;
  # 3. the email is marked sent and email_sent logged with the exact text.
  #
  # If the service certainly did not send it (Delivery::NotSent), the email
  # goes back to held. If nobody knows (Delivery::OutcomeUnknown, step 3
  # failing, or the process dying after step 1), it stays sending; once
  # that is stale the queue shows "Outcome unknown" and staff, having
  # checked the admissions@ Sent folder, say which it was.
  #
  # Locks are taken applicant first, then its emails, everywhere (as
  # withdrawal does), so a send and a withdrawal can't deadlock.
  #
  # Raises, for staff: MissingTemplate and EmailTemplate::RenderError when
  # an email can't be drafted, NotSendable for an email or applicant that
  # can't take the action, ApplicantChanges::NotPermitted for the wrong
  # actor, and Delivery::NotSent or Delivery::OutcomeUnknown when a send
  # that ran at once failed.
  class EmailSender
    include ServiceWrite

    class MissingTemplate < StandardError; end
    class NotSendable < StandardError; end

    NotPermitted = ApplicantChanges::NotPermitted

    def self.request_automatic!(applicant, type, values: {})
      new(Actor.system).request_automatic!(applicant, type, values: values)
    end

    attr_reader :actor

    def initialize(actor, delivery: nil)
      @actor = actor
      @delivery = delivery
      validate_actor!
    end

    # Returns the email (held; or sending or sent, on automatic), or nil
    # when nothing was drafted. Never raises for a failed send: the email
    # goes back to held, or waits as outcome unknown, for staff.
    def request_automatic!(applicant, type, values: {})
      raise NotPermitted, "#{actor} may not ask for an automatic email" unless actor.system?

      check_type!(type)
      email, message = service_write do
        fresh = Applicant.lock.find(applicant.id)
        mode = fresh.round.email_mode(type)
        reason = skip_reason(fresh, mode)
        if reason
          log!(fresh, 'email_skipped', timestamp, details: { 'email_type' => type, 'reason' => reason, 'mode' => mode })
          next
        end

        drafted = draft_automatic(fresh, type, values, mode)
        next unless drafted

        [drafted, (mode == 'automatic' ? begin_sending(fresh, drafted) : nil)]
      end
      send_after_commit(email, message, raise_errors: false) if message
      email
    end

    # An email staff send with a button (invitation, task, offer, …): the
    # click is the approval, so it is drafted and sent at once, whatever the
    # type's mode and even while the applicant is paused or "it's
    # complicated" — those stop only automatic email.
    def send_now!(applicant, type, values: {})
      require_staff!('send an email')
      check_type!(type)
      email, message = service_write do
        fresh = Applicant.lock.find(applicant.id)
        raise NotSendable, 'a withdrawn applicant gets no email' if fresh.withdrawn?

        drafted = draft(fresh, type, render!(fresh, type, values), nil)
        [drafted, begin_sending(fresh, drafted)]
      end
      send_after_commit(email, message, raise_errors: true)
      email
    end

    # Approval queue: change a held email's text before it is sent.
    def edit!(email, subject:, body:)
      require_staff!('edit an email')
      locked(email, 'held') do |applicant, fresh, now|
        fresh.assign_attributes(subject: subject.to_s.strip, body: body.to_s.gsub("\r\n", "\n"))
        next unless fresh.changed?

        fresh.update!(edited_by_type: actor.type, edited_by_user: actor.user, edited_at: now)
        log!(applicant, 'email_edited', now, details: fresh.event_details, body: fresh.text)
      end
    end

    # Approval queue: approve and send a held email.
    def send_held!(email)
      require_staff!('send an email')
      message = nil
      locked(email, 'held') { |applicant, fresh, _now| message = begin_sending(applicant, fresh) }
      send_after_commit(email, message, raise_errors: true)
      email
    end

    # Approval queue: never send it.
    def discard!(email)
      require_staff!('discard an email')
      locked(email, 'held') do |applicant, fresh, now|
        discard(applicant, fresh, now)
      end
    end

    # Approval queue, for a send whose outcome is unknown: staff found it
    # in the admissions@ Sent folder.
    def confirm_sent!(email)
      require_staff!('confirm an email was sent')
      locked(email, 'sending') do |applicant, fresh, now|
        raise NotSendable, 'this email is still being sent' unless fresh.outcome_unknown?

        fresh.update!(status: 'sent', sent_at: now, delivery: 'confirmed_by_staff')
        log!(applicant, 'email_sent', now, details: fresh.event_details.merge('confirmed_by_staff' => true),
                                           body: text_of(fresh))
      end
    end

    # Approval queue, for a send whose outcome is unknown: it isn't in the
    # Sent folder, so it goes back to held (or is discarded, if the
    # applicant has since withdrawn).
    def confirm_not_sent!(email)
      require_staff!('confirm an email was not sent')
      locked(email, 'sending') do |applicant, fresh, now|
        raise NotSendable, 'this email is still being sent' unless fresh.outcome_unknown?

        unsend(applicant, fresh, now, 'email_returned_to_held', 'confirmed_by_staff' => true)
      end
    end

    private

    def delivery
      @delivery || Delivery.adapter
    end

    def validate_actor!
      raise ArgumentError, "unknown actor #{actor.inspect}" unless actor.is_a?(Actor)
      return unless actor.staff?
      return if actor.user && Ability.new(actor.user).can?(:update, Email)

      raise NotPermitted, 'only admissions staff can act as staff'
    end

    def require_staff!(what)
      raise NotPermitted, "#{actor} may not #{what}" unless actor.staff?
    end

    def check_type!(type)
      raise ArgumentError, "unknown email type #{type}" unless EmailTypes::TYPES.key?(type)
    end

    def skip_reason(applicant, mode)
      return 'withdrawn' if applicant.withdrawn?
      return 'complicated' if applicant.complicated?
      return 'paused' if applicant.emails_paused?

      'off' if mode == 'off'
    end

    def render!(applicant, type, values)
      template = applicant.round.email_template(type)
      unless template
        raise MissingTemplate,
              "There is no #{EmailTypes.label(type)} template for #{applicant.round.name}: " \
              'add one under Admissions, Email templates, before this email can be drafted'
      end

      template.render(applicant, values)
    end

    # An automatic email that can't be drafted is logged, not raised, so the
    # action that asked for it (an EOI arriving, say) is never lost for it.
    def draft_automatic(applicant, type, values, mode)
      draft(applicant, type, render!(applicant, type, values), mode)
    rescue MissingTemplate, EmailTemplate::RenderError => e
      reason = e.is_a?(MissingTemplate) ? 'missing_template' : 'placeholder_unfilled'
      log!(applicant, 'email_not_drafted', timestamp,
           details: { 'email_type' => type, 'reason' => reason, 'mode' => mode, 'error' => e.message })
      nil
    end

    # Puts the rendered email in the outbox, held.
    def draft(applicant, type, rendered, mode)
      now = timestamp
      email = Email.create!(applicant: applicant, email_type: type, status: 'held',
                            subject: rendered.subject, body: rendered.body,
                            drafted_by_type: actor.type, drafted_by_user: actor.user, drafted_at: now)
      log!(applicant, 'email_drafted', now, details: email.event_details.merge({ 'mode' => mode }.compact),
                                            body: email.text)
      email
    end

    # Step 1, inside the caller's guarded write with the applicant and the
    # email locked: mark it sending, approved by this actor, and return the
    # message exactly as it will go.
    def begin_sending(applicant, email)
      raise NotSendable, 'a withdrawn applicant gets no email' if applicant.withdrawn?

      now = timestamp
      email.update!(status: 'sending', sending_at: now, to_address: applicant.email,
                    sent_by_type: actor.type, sent_by_user: actor.user)
      log!(applicant, 'email_sending', now, details: email.event_details, body: email.text)
      Delivery::Message.new(to: applicant.email, subject: email.subject, body: email.body, email_id: email.id)
    end

    # Steps 2 and 3, once every open transaction has committed (at once if
    # none is open). A staff send that ran at once raises its failure for
    # the screen to show; an automatic one, or one run later at a commit,
    # never raises: its outcome is in the log and the queue.
    def send_after_commit(email, message, raise_errors:)
      error = nil
      ActiveRecord.after_all_transactions_commit do
        deliver(email, message)
      rescue StandardError => e
        error = e
        Rails.logger.error("[admissions] email ##{email.id} not sent: #{e.class}: #{e.message}")
      end
      raise error if raise_errors && error
    end

    def deliver(email, message)
      receipt = begin
        delivery.deliver(message)
      rescue Delivery::NotSent => e
        not_sent(email, e)
        raise
      rescue StandardError => e
        outcome_unknown(email, e)
        raise e.is_a?(Delivery::OutcomeUnknown) ? e : Delivery::OutcomeUnknown.new("#{e.class}: #{e.message}")
      end

      begin
        locked(email, 'sending') do |applicant, fresh, now|
          fresh.update!(status: 'sent', sent_at: now, delivery: receipt.delivery,
                        delivery_message_id: receipt.message_id)
          log!(applicant, 'email_sent', now,
               details: fresh.event_details.merge('delivery' => receipt.delivery,
                                                  'delivery_message_id' => receipt.message_id),
               body: text_of(fresh))
        end
      rescue StandardError => e
        outcome_unknown(email, e)
        raise Delivery::OutcomeUnknown, "the email went, but recording it failed (#{e.class})"
      end
    end

    def not_sent(email, error)
      locked(email, 'sending') do |applicant, fresh, now|
        unsend(applicant, fresh, now, 'email_send_failed', 'error' => error.message)
      end
    end

    # Best effort: the email stays sending whatever happens here.
    def outcome_unknown(email, error)
      locked(email, 'sending') do |applicant, fresh, now|
        fresh.update!(outcome_unknown_at: now)
        log!(applicant, 'email_outcome_unknown', now,
             details: fresh.event_details.merge('error' => "#{error.class}: #{error.message}"))
      end
    rescue StandardError => e
      Rails.logger.error("[admissions] email ##{email.id}: could not record the unknown outcome: #{e.class}")
    end

    # Back to held, ready to send again; or discarded, for an applicant who
    # withdrew meanwhile.
    def unsend(applicant, email, now, kind, details)
      email.update!(status: 'held', sending_at: nil, outcome_unknown_at: nil, to_address: nil,
                    sent_by_type: nil, sent_by_user: nil)
      log!(applicant, kind, now, details: email.event_details.merge(details))
      discard(applicant, email, now, 'reason' => 'withdrawn') if applicant.withdrawn?
    end

    def discard(applicant, email, now, details = {})
      email.update!(status: 'discarded', discarded_by_type: actor.type, discarded_by_user: actor.user,
                    discarded_at: now)
      log!(applicant, 'email_discarded', now, details: email.event_details.merge(details), body: text_of(email))
    end

    # Locks the applicant, then a fresh copy of the email, in one guarded
    # transaction, and checks the email is in the expected status before
    # the block changes it. The caller's object is reloaded afterwards.
    def locked(email, status)
      service_write do
        applicant = Applicant.lock.find(email.applicant_id)
        fresh = Email.lock.find(email.id)
        raise NotSendable, already(fresh) unless fresh.status == status

        yield applicant, fresh, timestamp
      end
      email.reload
    end

    def already(email)
      email.status == 'sending' ? 'this email is being sent' : "this email has already been #{email.status}"
    end

    # The text, unless withdrawal has blanked it.
    def text_of(email) = email.redacted? ? nil : email.text

    def log!(applicant, kind, now, details: {}, body: nil)
      ApplicantEvent.create!(applicant: applicant, kind: kind, actor_type: actor.type, actor_user: actor.user,
                             details: details, body: body, created_at: now)
    end
  end
end
