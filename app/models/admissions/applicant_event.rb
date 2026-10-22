module Admissions
  # The append-only event log (SPEC §1, §2): one row per thing that happens to
  # an applicant, naming who acted — a staff user, the applicant, or the
  # system. Rows are never updated or deleted. The one exception is
  # .redact_bodies_for, which blanks an applicant's free text when they
  # withdraw (SPEC §9b), leaving the rows themselves in place.
  #
  # `details` holds structured, non-personal data (dates, stages, field
  # names); anything a person wrote goes in `body`, so it can be scrubbed.
  class ApplicantEvent < ActiveRecord::Base
    KINDS = %w[
      created advanced held returned_from_hold moved exited reopened
      flagged_complicated cleared_complicated note_added details_changed
      emails_paused emails_resumed
      email_drafted email_edited email_sent email_send_failed email_discarded email_skipped
    ].freeze
    EMAIL_KINDS = KINDS.grep(/\Aemail_/).freeze

    belongs_to :applicant, class_name: 'Admissions::Applicant', inverse_of: :events
    belongs_to :actor_user, class_name: 'User', optional: true

    validates :kind, inclusion: { in: KINDS }
    validates :actor_type, inclusion: { in: Stages::ACTOR_TYPES }
    validates :actor_user, presence: true, if: -> { actor_type == 'staff' }
    validates :actor_user, absence: true, unless: -> { actor_type == 'staff' }
    validates :from_stage, :to_stage, inclusion: { in: Stages::ALL }, allow_nil: true

    def readonly?
      persisted? || super
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, 'The admissions event log is append-only'
    end

    def self.redact_bodies_for(applicant, at:)
      where(applicant_id: applicant.id).where.not(body: nil).update_all(body: nil, redacted_at: at)
    end

    def actor
      Actor.new(actor_type, actor_user)
    end

    # An email event's body is the email's exact text as
    # Email#text writes it: "Subject: …", a blank line, then the body. The
    # subject never holds a line break, so the split is unambiguous. Returns
    # [subject, body], or nil when there is no text (or it was redacted).
    def email_text
      return nil unless EMAIL_KINDS.include?(kind) && body

      subject, text = body.split("\n\n", 2)
      [subject.delete_prefix('Subject: '), text.to_s]
    end
  end
end
