module Admissions
  # Backups of the admissions data (SPEC §1 Principle 1, §9b "Backups",
  # Q34): every admissions table, plus the id and email of each staff user
  # the rows point to and nothing else from users, as one file.
  #
  # - Snapshot reads every table in one SQL statement, so the tables agree
  #   with each other.
  # - Archive is the file: gzipped JSON Lines, a header line then a data
  #   line, the header carrying the schema version, when it was taken, the
  #   row counts and the data line's checksum.
  # - Nightly emails it to the admissions leads when the data changed since
  #   the last backup it emailed, and records every run (BackupRun).
  # - Restore puts a file back into a database whose admissions tables are
  #   empty.
  #
  # The rest of the site's database is backed up by the server's owner, not
  # here (Q34).
  module Backup
    class Error < StandardError; end

    # Every admissions table, each after the tables it points to, which is
    # the order Restore writes them in. A new admissions table must be added
    # here: Snapshot refuses to run while one is missing, rather than leave
    # it out of the backup.
    TABLES = %w[
      admissions_rounds
      admissions_staff_members
      admissions_form_texts
      admissions_email_templates
      admissions_applicants
      admissions_emails
      admissions_applicant_events
      admissions_backup_runs
    ].freeze
    # The backup log itself, which every run adds to: it is in the file, but
    # not in the content checksum that decides whether anything changed.
    LOG_TABLE = 'admissions_backup_runs'.freeze

    def self.tables_in_database(connection = ActiveRecord::Base.connection)
      connection.tables.grep(/\Aadmissions_/).sort
    end

    # The columns of a table that point at users, read from its foreign
    # keys, so a new staff column is carried without a change here.
    def self.user_columns(table, connection = ActiveRecord::Base.connection)
      connection.foreign_keys(table).select { |fk| fk.to_table == 'users' }.map(&:column).sort
    end

    def self.schema_version(connection = ActiveRecord::Base.connection)
      connection.pool.migration_context.current_version
    end

    def self.sha256(text) = "sha256:#{Digest::SHA256.hexdigest(text)}"

    # Who gets the nightly backup: every admissions lead (SPEC §9b: staff
    # are role-holding accounts, never a hard-coded Ed).
    def self.recipients
      StaffMember.where(role: 'lead').includes(:user).map { |staff| staff.user.email }.sort
    end
  end
end
