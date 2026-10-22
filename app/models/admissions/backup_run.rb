module Admissions
  # One night's backup of the admissions data (SPEC §1 Principle 1, §9b,
  # Q34), written once when the run ends by Backup::Nightly:
  #
  # - sent: the data had changed since the last backup emailed, so a new
  #   one was emailed to the admissions leads;
  # - unchanged: nothing changed since then, so nothing was sent;
  # - failed: the export, the size check or the delivery failed (including
  #   a delivery whose outcome is unknown), and `error` says how.
  #
  # Rows are never changed or deleted (a database trigger holds that). The
  # staff home warns while the latest run failed, or while no run has been
  # recorded for longer than a night should take.
  class BackupRun < ActiveRecord::Base
    OUTCOMES = %w[sent unchanged failed].freeze
    # A nightly run that hasn't happened for this long has been missed.
    OVERDUE_AFTER = 26.hours

    validates :outcome, inclusion: { in: OUTCOMES }
    validates :started_at, :finished_at, presence: true
    validates :error, presence: true, if: :failed?
    validates :content_checksum, presence: true, unless: :failed?

    def readonly?
      persisted? || super
    end

    def self.latest = order(:id).last
    def self.last_sent = where(outcome: 'sent').order(:id).last
    def self.last_success = where(outcome: %w[sent unchanged]).order(:id).last

    # What the staff home warns about, or nil when backups are healthy:
    # [:failed, latest_run] while the latest run failed, until a later one
    # succeeds; [:overdue, latest_run_or_nil] once there is applicant data
    # and no run has been recorded within OVERDUE_AFTER (the nightly job
    # isn't running at all).
    def self.warning(now: Time.current)
      latest = self.latest
      return [:failed, latest] if latest&.failed?
      return nil unless Applicant.exists?
      return [:overdue, latest] if latest.nil? || latest.finished_at < now - OVERDUE_AFTER

      nil
    end

    OUTCOMES.each { |o| define_method(:"#{o}?") { outcome == o } }

    # The failures since the last success, oldest first: how long backups
    # have been failing.
    def self.failures_since_last_success
      success = last_success
      scope = where(outcome: 'failed')
      scope = scope.where('id > ?', success.id) if success
      scope.order(:id)
    end

    def recording? = delivery == 'recording'
  end
end
