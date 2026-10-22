module Admissions
  # One email to one applicant, in the outbox (SPEC §2 email-sender, §3a):
  # drafted with its exact text, then
  #
  # - held, awaiting a staff member's approval in the approval queue;
  # - sent, by staff approving it or by the system for an automatic type;
  # - discarded.
  #
  # Each records who drafted, last edited, sent or discarded it, and when.
  # Whoever sent it approved it: the click that sends is the approval, and
  # the system approves only types whose mode is automatic.
  #
  # Written only by Admissions::EmailSender (and withdrawal's scrub), which
  # logs every draft, edit, send and discard as an applicant event with the
  # exact text. A database trigger refuses any other write, any delete, and
  # any change to an email once it is sent or discarded, except withdrawal
  # blanking its text and address.
  class Email < ActiveRecord::Base
    STATUSES = %w[held sent discarded].freeze

    belongs_to :applicant, class_name: 'Admissions::Applicant', inverse_of: :emails
    %i[drafted edited sent discarded].each do |act|
      belongs_to :"#{act}_by_user", class_name: 'User', optional: true
    end

    validates :email_type, inclusion: { in: EmailTypes.keys }
    validates :status, inclusion: { in: STATUSES }
    validates :subject, :body, presence: true, unless: :redacted?
    validates :subject, format: { without: /[\r\n]/, message: 'must be one line' }, allow_nil: true
    validates :drafted_by_type, inclusion: { in: Stages::ACTOR_TYPES }
    validate :written_through_service

    before_destroy(prepend: true) do
      raise ActiveRecord::ReadOnlyRecord, 'Admissions emails are never deleted; discard them instead'
    end

    scope :held, -> { where(status: 'held') }
    scope :sent, -> { where(status: 'sent') }

    def held? = status == 'held'
    def sent? = status == 'sent'
    def discarded? = status == 'discarded'
    def redacted? = redacted_at.present?

    def label = EmailTypes.label(email_type)

    %i[drafted edited sent discarded].each do |act|
      define_method(:"#{act}_by") do
        type = public_send(:"#{act}_by_type")
        type && Actor.new(type, public_send(:"#{act}_by_user"))
      end
    end

    # The exact text as one string, as the event log records it.
    def text
      "Subject: #{subject}\n\n#{body}"
    end

    # The structured part of every event about this email; the text goes in
    # the event's body, so that withdrawal can blank it.
    def event_details
      { 'email_id' => id, 'email_type' => email_type }
    end

    # Withdrawal (SPEC §9b): blank the text and address of every one of the
    # applicant's emails. Runs inside ApplicantChanges' guarded write.
    def self.redact_for(applicant, at:)
      where(applicant_id: applicant.id, redacted_at: nil)
        .update_all(subject: nil, body: nil, to_address: nil, redacted_at: at)
    end

    private

    def written_through_service
      return if Applicant.service_write_allowed?

      errors.add(:base, 'Admissions emails change only through Admissions::EmailSender')
    end
  end
end
