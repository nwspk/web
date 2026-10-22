# admit: nightly backups of the admissions data (spec: nwspk/admit SPEC.md
# §1 Principle 1, §9b "Backups", §10 Q34).
#
# One row per night the backup ran, written once when the run ends: whether
# it emailed a backup, found nothing changed since the last one it emailed,
# or failed, and why. The next night compares its content checksum with
# the last emailed run's, and the staff home warns while the latest run
# failed. Rows are never changed or deleted.
class CreateAdmissionsBackupRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :admissions_backup_runs do |t|
      t.string :outcome, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at, null: false
      t.bigint :schema_version
      t.string :content_checksum
      t.string :file_name
      t.string :file_checksum
      t.integer :file_bytes
      t.jsonb :row_counts, default: {}, null: false
      t.jsonb :recipients, default: [], null: false
      t.string :delivery
      t.string :delivery_message_id
      t.text :error
      t.datetime :created_at, null: false

      t.check_constraint "outcome IN ('sent', 'unchanged', 'failed')", name: 'admissions_backup_runs_outcome'
      t.check_constraint "outcome <> 'failed' OR error IS NOT NULL", name: 'admissions_backup_runs_failed_error'
      t.check_constraint "outcome = 'failed' OR content_checksum IS NOT NULL",
                         name: 'admissions_backup_runs_checksum'
    end
    add_index :admissions_backup_runs, %i[outcome id]

    reversible do |dir|
      dir.up { execute GUARDS }
      dir.down { execute DROP_GUARDS }
    end
  end

  GUARDS = <<~SQL.freeze
    CREATE OR REPLACE FUNCTION admissions_backup_runs_append_only() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      RAISE EXCEPTION 'the admissions backup log is append-only';
    END
    $$;

    CREATE TRIGGER admissions_backup_runs_append_only
      BEFORE UPDATE OR DELETE ON admissions_backup_runs
      FOR EACH ROW EXECUTE FUNCTION admissions_backup_runs_append_only();

    CREATE TRIGGER admissions_backup_runs_no_truncate
      BEFORE TRUNCATE ON admissions_backup_runs
      FOR EACH STATEMENT EXECUTE FUNCTION admissions_backup_runs_append_only();
  SQL

  DROP_GUARDS = <<~SQL.freeze
    DROP TRIGGER IF EXISTS admissions_backup_runs_no_truncate ON admissions_backup_runs;
    DROP TRIGGER IF EXISTS admissions_backup_runs_append_only ON admissions_backup_runs;
    DROP FUNCTION IF EXISTS admissions_backup_runs_append_only();
  SQL
end
