# admit phase 0a: the applicant record, the append-only event log and the
# admissions staff roles (spec: nwspk/admit SPEC.md §2, §3, §3a, §9b).
class CreateAdmissionsFoundations < ActiveRecord::Migration[7.2]
  def change
    create_table :admissions_rounds do |t|
      t.string :name, null: false
      t.date :opens_on
      t.date :invites_on
      t.date :closes_on
      t.datetime :closed_at
      t.timestamps
    end
    add_index :admissions_rounds, :name, unique: true

    # Admissions staff are site users with an admissions role, kept apart
    # from users.role so a site admin or staff user can also be admissions
    # staff (and a site admin is not admissions staff by default).
    create_table :admissions_staff_members do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :role, null: false
      t.timestamps
    end

    create_table :admissions_applicants do |t|
      t.references :round, null: false, foreign_key: { to_table: :admissions_rounds }
      # Earlier round's record for the same person (re-applicants).
      t.references :previous_applicant, foreign_key: { to_table: :admissions_applicants }

      # Personal fields: scrubbed to NULL when the applicant withdraws.
      t.string :email
      t.string :phone
      t.string :name

      # Cached state, derived from the event log and written only by
      # Admissions::ApplicantChanges in the same transaction as its event.
      t.string :stage, null: false
      t.datetime :stage_entered_at, null: false
      t.string :held_from_stage
      t.text :hold_reason
      t.date :hold_until
      t.string :exited_from_stage
      t.boolean :complicated, null: false, default: false
      t.text :complicated_note
      t.date :complicated_check_back_on

      t.timestamps

      # A withdrawn stub keeps no contact details (SPEC §9b).
      t.check_constraint "stage <> 'withdrawn' OR (email IS NULL AND phone IS NULL AND name IS NULL)",
                         name: 'admissions_applicants_withdrawn_scrubbed'
    end
    add_index :admissions_applicants, :stage
    add_index :admissions_applicants, 'round_id, lower(email)', unique: true,
              where: 'email IS NOT NULL', name: 'index_admissions_applicants_on_round_and_email'

    # Append-only: rows are never updated or deleted, except that a
    # withdrawal blanks the free-text body of that applicant's rows.
    create_table :admissions_applicant_events do |t|
      t.references :applicant, null: false, foreign_key: { to_table: :admissions_applicants }
      t.string :kind, null: false
      t.string :actor_type, null: false
      t.references :actor_user, foreign_key: { to_table: :users }
      t.string :from_stage
      t.string :to_stage
      t.jsonb :details, null: false, default: {}
      t.text :body
      t.datetime :redacted_at
      t.datetime :created_at, null: false
    end
    add_index :admissions_applicant_events, :kind

    reversible do |dir|
      dir.up { execute GUARDS }
      dir.down { execute DROP_GUARDS }
    end
  end

  # Database-level guards, so the rules hold whatever Ruby does (update_all,
  # update_columns, raw SQL). db/schema.rb carries them too: see
  # config/initializers/schema_dumper_triggers.rb.
  #
  # - Applicant rows are written only inside Admissions::ApplicantChanges,
  #   which sets admissions.service_write for the length of its transaction:
  #   without it, inserts and changes to the cached state or the contact
  #   details are refused. Applicants are never deleted.
  # - The event log is append-only: no DELETE or TRUNCATE, and the only
  #   UPDATE allowed blanks body and stamps redacted_at (withdrawal).
  GUARDS = <<~SQL.freeze
    CREATE OR REPLACE FUNCTION admissions_applicants_guard() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'admissions applicants are never deleted; withdraw them instead';
      END IF;
      IF current_setting('admissions.service_write', true) IS DISTINCT FROM 'on' THEN
        IF TG_OP = 'INSERT' THEN
          RAISE EXCEPTION 'admissions applicants are created only through Admissions::ApplicantChanges';
        END IF;
        IF (NEW.stage, NEW.stage_entered_at, NEW.held_from_stage, NEW.hold_reason, NEW.hold_until,
            NEW.exited_from_stage, NEW.complicated, NEW.complicated_note, NEW.complicated_check_back_on,
            NEW.email, NEW.phone, NEW.name)
           IS DISTINCT FROM
           (OLD.stage, OLD.stage_entered_at, OLD.held_from_stage, OLD.hold_reason, OLD.hold_until,
            OLD.exited_from_stage, OLD.complicated, OLD.complicated_note, OLD.complicated_check_back_on,
            OLD.email, OLD.phone, OLD.name) THEN
          RAISE EXCEPTION 'admissions applicant state and contact details change only through Admissions::ApplicantChanges';
        END IF;
      END IF;
      RETURN NEW;
    END
    $$;

    CREATE TRIGGER admissions_applicants_guard
      BEFORE INSERT OR UPDATE OR DELETE ON admissions_applicants
      FOR EACH ROW EXECUTE FUNCTION admissions_applicants_guard();

    CREATE OR REPLACE FUNCTION admissions_applicant_events_append_only() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'UPDATE'
         AND NEW.body IS NULL AND NEW.redacted_at IS NOT NULL
         AND (NEW.id, NEW.applicant_id, NEW.kind, NEW.actor_type, NEW.actor_user_id,
              NEW.from_stage, NEW.to_stage, NEW.details, NEW.created_at)
             IS NOT DISTINCT FROM
             (OLD.id, OLD.applicant_id, OLD.kind, OLD.actor_type, OLD.actor_user_id,
              OLD.from_stage, OLD.to_stage, OLD.details, OLD.created_at) THEN
        RETURN NEW;
      END IF;
      RAISE EXCEPTION 'the admissions event log is append-only';
    END
    $$;

    CREATE TRIGGER admissions_applicant_events_append_only
      BEFORE UPDATE OR DELETE ON admissions_applicant_events
      FOR EACH ROW EXECUTE FUNCTION admissions_applicant_events_append_only();

    CREATE TRIGGER admissions_applicant_events_no_truncate
      BEFORE TRUNCATE ON admissions_applicant_events
      FOR EACH STATEMENT EXECUTE FUNCTION admissions_applicant_events_append_only();
  SQL

  DROP_GUARDS = <<~SQL.freeze
    DROP TRIGGER IF EXISTS admissions_applicant_events_no_truncate ON admissions_applicant_events;
    DROP TRIGGER IF EXISTS admissions_applicant_events_append_only ON admissions_applicant_events;
    DROP FUNCTION IF EXISTS admissions_applicant_events_append_only();
    DROP TRIGGER IF EXISTS admissions_applicants_guard ON admissions_applicants;
    DROP FUNCTION IF EXISTS admissions_applicants_guard();
  SQL
end
