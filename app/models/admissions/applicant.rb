module Admissions
  # One applicant per person per round (SPEC §2 applicant-database, §3).
  #
  # The stage and the hold / exit / "it's complicated" columns are a cache of
  # the event log (SPEC §1: the log is the truth). They, and the contact
  # details, are written only by Admissions::ApplicantChanges, which records
  # the event in the same transaction. Anything else is refused twice: by
  # validation here, and by a database trigger (see the migration) that
  # checks the same admissions.service_write setting.
  class Applicant < ActiveRecord::Base
    PERSONAL_FIELDS = %i[email phone name].freeze
    STATE_FIELDS = %i[
      stage stage_entered_at held_from_stage hold_reason hold_until
      exited_from_stage complicated complicated_note complicated_check_back_on emails_paused
    ].freeze
    GUARDED_FIELDS = (STATE_FIELDS + PERSONAL_FIELDS).freeze

    belongs_to :round, class_name: 'Admissions::Round', inverse_of: :applicants
    belongs_to :previous_applicant, class_name: 'Admissions::Applicant', optional: true
    has_many :later_applicants, class_name: 'Admissions::Applicant', foreign_key: :previous_applicant_id,
                                inverse_of: :previous_applicant, dependent: :restrict_with_exception
    has_many :events, -> { order(:id) }, class_name: 'Admissions::ApplicantEvent', inverse_of: :applicant,
                                         dependent: :restrict_with_exception
    has_many :emails, -> { order(:id) }, class_name: 'Admissions::Email', inverse_of: :applicant,
                                         dependent: :restrict_with_exception

    validates :email, presence: true, unless: :withdrawn?
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
    validates :email, uniqueness: { scope: :round_id, case_sensitive: false }, allow_nil: true
    validates :stage, inclusion: { in: Stages::ALL }
    validates :stage_entered_at, presence: true
    validates :held_from_stage, presence: true, if: :on_hold?
    validate :guarded_fields_changed_through_service

    before_destroy(prepend: true) do
      raise ActiveRecord::ReadOnlyRecord, 'Applicants are never deleted; withdraw them instead'
    end

    scope :active, -> { where.not(stage: Stages::TERMINAL) }
    # Flagged "it's complicated" with the check-back date come (SPEC §3a).
    scope :check_back_due, lambda { |on = Date.current|
      active.where(complicated: true).where(complicated_check_back_on: ..on)
    }
    # On hold with the return date come: staff return them (SPEC §3a).
    scope :hold_return_due, ->(on = Date.current) { where(stage: Stages::ON_HOLD, hold_until: ..on) }

    # True only inside an admissions service's guarded transaction
    # (Admissions::ServiceWrite).
    def self.service_write_allowed?
      service_write_setting == 'on'
    end

    # Read past the query cache, which inside a web request would otherwise
    # answer with the setting as it was at the first read.
    def self.service_write_setting
      uncached { connection.select_value("SELECT current_setting('admissions.service_write', true)") }
    end

    def on_hold? = stage == Stages::ON_HOLD
    def withdrawn? = stage == 'withdrawn'
    def terminal? = Stages.terminal?(stage)

    # The stage this applicant is really at: the held-from stage while on hold.
    def funnel_stage
      on_hold? ? held_from_stage : stage
    end

    # Next step, owner (:applicant, :staff or :date) and due time (SPEC §3a
    # "Nobody gets lost"); nil once terminal.
    def next_step(now: Time.current)
      NextStep.for(self, now: now)
    end

    # When the system last contacted the applicant: the latest email sent,
    # or entering the current stage if that came later.
    def last_contacted_at
      [stage_entered_at, emails.sent.maximum(:sent_at)].compact.max
    end

    # How staff screens name the applicant: their name once known, else
    # their address; a withdrawn record has neither.
    def display_name
      name.presence || email.presence || "Withdrawn applicant ##{id}"
    end

    def created_event
      events.find_by(kind: 'created')
    end

    # The day this person first expressed interest (SPEC §3a "Cards created
    # by hand"): the date staff entered on a card created by hand, which the
    # `created` event keeps as details['first_interest_on'], or else the
    # day the record was created. funnel-stats reads it from there.
    def first_interest_on
      event = created_event
      return nil unless event

      given = event.details['first_interest_on']
      given ? Date.iso8601(given) : event.created_at.to_date
    end

    # This person's records in every round, oldest first: the chain of
    # previous_applicant links, followed both ways. Withdrawal scrubs one
    # record; a full erasure is staff withdrawing each of these.
    def person_records
      first = self
      seen = [id]
      while first.previous_applicant && !seen.include?(first.previous_applicant_id)
        seen << first.previous_applicant_id
        first = first.previous_applicant
      end
      records = [first]
      while (later = records.last.later_applicants.where.not(id: records.map(&:id)).order(:id).first)
        records << later
      end
      records
    end

    private

    def guarded_fields_changed_through_service
      return unless GUARDED_FIELDS.any? { |f| will_save_change_to_attribute?(f) }
      return if self.class.service_write_allowed?

      errors.add(:base, 'Applicant state and contact details change only through Admissions::ApplicantChanges')
    end
  end
end
