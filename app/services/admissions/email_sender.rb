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
  # and the approval queue's actions, for staff: edit!, send_held! and
  # discard!.
  #
  # An automatic email follows its type's mode in the applicant's round:
  # off drafts nothing, ask me first drafts and holds it, automatic drafts
  # and sends it. Whatever the mode, nothing automatic is drafted for an
  # applicant who is withdrawn, flagged "it's complicated", or paused. Each
  # skip leaves an email_skipped event saying why.
  #
  # Raises MissingTemplate when the round has no template for the type,
  # EmailTemplate::RenderError when a placeholder can't be filled,
  # NotSendable for an email or applicant that can't take this action,
  # ApplicantChanges::NotPermitted for the wrong actor, and Delivery::Error
  # when a staff send fails (the email stays held).
  class EmailSender
    include ServiceWrite

    class MissingTemplate < StandardError; end
    class NotSendable < StandardError; end

    NotPermitted = ApplicantChanges::NotPermitted

    # Why an automatic email was not drafted, in the order they are checked.
    SKIP_REASONS = {
      'withdrawn' => 'the applicant has withdrawn',
      'complicated' => "the applicant is flagged \"it's complicated\"",
      'paused' => 'automatic email to the applicant is paused',
      'off' => "this email type's mode is off"
    }.freeze

    def self.request_automatic!(applicant, type, values: {})
      new(Actor.system).request_automatic!(applicant, type, values: values)
    end

    attr_reader :actor

    def initialize(actor, delivery: nil)
      @actor = actor
      @delivery = delivery
      validate_actor!
    end

    # Returns the email, held or sent, or nil when it was skipped. A failed
    # automatic send leaves the email held for staff, with an
    # email_send_failed event, rather than losing it.
    def request_automatic!(applicant, type, values: {})
      raise NotPermitted, "#{actor} may not ask for an automatic email" unless actor.system?

      check_type!(type)
      email, mode = service_write do
        fresh = Applicant.lock.find(applicant.id)
        mode = fresh.round.email_mode(type)
        reason = skip_reason(fresh, mode)
        if reason
          log!(fresh, 'email_skipped', timestamp, details: { 'email_type' => type, 'reason' => reason, 'mode' => mode })
          nil
        else
          [draft(fresh, type, values, mode), mode]
        end
      end
      return nil unless email

      begin
        deliver!(email) if mode == 'automatic'
      rescue Delivery::Error
        email.reload
      end
      email
    end

    # An email staff send with a button (invitation, task, offer, …): the
    # click is the approval, so it is drafted and sent at once, whatever the
    # type's mode and even while the applicant is paused or "it's
    # complicated" — those stop only automatic email.
    def send_now!(applicant, type, values: {})
      require_staff!('send an email')
      check_type!(type)
      email = service_write do
        fresh = Applicant.lock.find(applicant.id)
        raise NotSendable, 'a withdrawn applicant gets no email' if fresh.withdrawn?

        draft(fresh, type, values, nil)
      end
      deliver!(email)
      email
    end

    # Approval queue: change a held email's text before it is sent.
    def edit!(email, subject:, body:)
      require_staff!('edit an email')
      change_held!(email) do |fresh, now|
        fresh.assign_attributes(subject: subject.to_s.strip, body: body.to_s.gsub("\r\n", "\n"))
        next unless fresh.changed?

        fresh.update!(edited_by_type: actor.type, edited_by_user: actor.user, edited_at: now)
        log!(fresh.applicant, 'email_edited', now, details: fresh.event_details, body: fresh.text)
      end
    end

    # Approval queue: approve and send a held email.
    def send_held!(email)
      require_staff!('send an email')
      deliver!(email)
      email
    end

    # Approval queue: never send it.
    def discard!(email)
      require_staff!('discard an email')
      change_held!(email) do |fresh, now|
        fresh.update!(status: 'discarded', discarded_by_type: actor.type, discarded_by_user: actor.user,
                      discarded_at: now)
        log!(fresh.applicant, 'email_discarded', now, details: fresh.event_details, body: fresh.text)
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

    # Renders the round's template and puts the email in the outbox, held.
    def draft(applicant, type, values, mode)
      template = applicant.round.email_template(type)
      unless template
        raise MissingTemplate,
              "There is no #{EmailTypes.label(type)} template for #{applicant.round.name}: " \
              'add one under Admissions, Email templates, before this email can be drafted'
      end

      rendered = template.render(applicant, values)
      now = timestamp
      email = Email.create!(applicant: applicant, email_type: type, status: 'held',
                            subject: rendered.subject, body: rendered.body,
                            drafted_by_type: actor.type, drafted_by_user: actor.user, drafted_at: now)
      log!(applicant, 'email_drafted', now, details: email.event_details.merge({ 'mode' => mode }.compact),
                                            body: email.text)
      email
    end

    # Sends a held email under a row lock, so two staff approving at once
    # send it once. The delivery runs inside the lock, then the email is
    # marked sent and the send logged; if delivery fails nothing is marked,
    # the email stays held and an email_send_failed event says why.
    def deliver!(email)
      change_held!(email) do |fresh, now|
        applicant = fresh.applicant
        raise NotSendable, 'a withdrawn applicant gets no email' if applicant.withdrawn?

        receipt = delivery.deliver(Delivery::Message.new(to: applicant.email, subject: fresh.subject,
                                                         body: fresh.body, email_id: fresh.id))
        fresh.update!(status: 'sent', to_address: applicant.email, sent_by_type: actor.type,
                      sent_by_user: actor.user, sent_at: now,
                      delivery: receipt.delivery, delivery_message_id: receipt.message_id)
        log!(applicant, 'email_sent', now,
             details: fresh.event_details.merge('delivery' => receipt.delivery,
                                                'delivery_message_id' => receipt.message_id),
             body: fresh.text)
      end
    rescue Delivery::Error => e
      service_write do
        log!(email.applicant, 'email_send_failed', timestamp,
             details: email.event_details.merge('error' => e.message))
      end
      raise
    end

    # Locks a fresh copy of a held email and lets the block change it, in
    # one guarded transaction; the caller's object is reloaded afterwards.
    def change_held!(email)
      service_write do
        fresh = Email.lock.find(email.id)
        raise NotSendable, "this email has already been #{fresh.status}" unless fresh.held?

        yield fresh, timestamp
      end
      email.reload
    end

    def log!(applicant, kind, now, details: {}, body: nil)
      ApplicantEvent.create!(applicant: applicant, kind: kind, actor_type: actor.type, actor_user: actor.user,
                             details: details, body: body, created_at: now)
    end
  end
end
