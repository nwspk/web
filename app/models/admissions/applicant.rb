module Admissions
  # One applicant per person per round (SPEC §2 applicant-database, §3).
  #
  # The stage and the hold / exit / "it's complicated" columns are a cache of
  # the event log (SPEC §1: the log is the truth). They are written only by
  # Admissions::ApplicantChanges, which records the event in the same
  # transaction; any other attempt to change them fails validation.
  class Applicant < ActiveRecord::Base
    PERSONAL_FIELDS = %i[email phone name].freeze
    STATE_FIELDS = %i[
      stage stage_entered_at held_from_stage hold_reason hold_until
      exited_from_stage complicated complicated_note complicated_check_back_on
    ].freeze

    belongs_to :round, class_name: 'Admissions::Round', inverse_of: :applicants
    belongs_to :previous_applicant, class_name: 'Admissions::Applicant', optional: true
    has_many :later_applicants, class_name: 'Admissions::Applicant', foreign_key: :previous_applicant_id,
                                inverse_of: :previous_applicant, dependent: :restrict_with_exception
    has_many :events, -> { order(:id) }, class_name: 'Admissions::ApplicantEvent', inverse_of: :applicant,
                                         dependent: :restrict_with_exception

    validates :email, presence: true, unless: :withdrawn?
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
    validates :email, uniqueness: { scope: :round_id, case_sensitive: false }, allow_nil: true
    validates :stage, inclusion: { in: Stages::ALL }
    validates :stage_entered_at, presence: true
    validates :held_from_stage, presence: true, if: :on_hold?
    validate :state_changed_through_service

    before_destroy { raise ActiveRecord::ReadOnlyRecord, 'Applicants are never deleted; withdraw them instead' }

    scope :active, -> { where.not(stage: Stages::TERMINAL) }

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

    # When the system last contacted the applicant. email-sender (phase 1)
    # will log sent emails; until then a stage change is the last contact.
    def last_contacted_at
      stage_entered_at
    end

    # Set only by ApplicantChanges while it writes the event for a change.
    def writing_through_service
      @writing_through_service = true
      yield
    ensure
      @writing_through_service = false
    end

    private

    def state_changed_through_service
      return if @writing_through_service
      return unless STATE_FIELDS.any? { |f| will_save_change_to_attribute?(f) }

      errors.add(:stage, 'can only change through Admissions::ApplicantChanges')
    end
  end
end
