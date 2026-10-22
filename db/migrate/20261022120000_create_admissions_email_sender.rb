# admit phase 1a: the email-sender (spec: nwspk/admit SPEC.md §2
# email-sender, §3a "Email modes", "Upcoming emails on every card", §4).
#
# - Email templates live in the database, one per round per email type, so
#   no admissions wording is published in this public repository (§9).
# - The outbox holds one row per email drafted to an applicant, with the
#   exact text: held for approval, sent, or discarded.
# - Each applicant gets a pause switch for automatic email.
class CreateAdmissionsEmailSender < ActiveRecord::Migration[7.2]
  def change
    create_table :admissions_email_templates do |t|
      t.references :round, null: false, foreign_key: { to_table: :admissions_rounds }
      t.string :email_type, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.references :updated_by_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :admissions_email_templates, %i[round_id email_type], unique: true

    # Written only by Admissions::EmailSender (and withdrawal's scrub), with
    # each draft, edit, send and discard also logged as an applicant event.
    create_table :admissions_emails do |t|
      t.references :applicant, null: false, foreign_key: { to_table: :admissions_applicants }
      t.string :email_type, null: false
      t.string :status, null: false, default: 'held'
      # Personal: the rendered text and the address it went to. Blanked when
      # the applicant withdraws.
      t.string :subject
      t.text :body
      t.string :to_address

      t.string :drafted_by_type, null: false
      t.references :drafted_by_user, foreign_key: { to_table: :users }
      t.datetime :drafted_at, null: false
      t.string :edited_by_type
      t.references :edited_by_user, foreign_key: { to_table: :users }
      t.datetime :edited_at
      # Whoever sent it approved it: the click that sends is the approval.
      t.string :sent_by_type
      t.references :sent_by_user, foreign_key: { to_table: :users }
      t.datetime :sent_at
      t.string :delivery
      t.string :delivery_message_id
      t.string :discarded_by_type
      t.references :discarded_by_user, foreign_key: { to_table: :users }
      t.datetime :discarded_at
      t.datetime :redacted_at

      t.check_constraint "status IN ('held', 'sent', 'discarded')", name: 'admissions_emails_status'
      t.check_constraint "status <> 'sent' OR sent_at IS NOT NULL", name: 'admissions_emails_sent_at'
      t.check_constraint "status <> 'discarded' OR discarded_at IS NOT NULL", name: 'admissions_emails_discarded_at'
    end
    add_index :admissions_emails, :status

    # The per-applicant pause switch (SPEC §3a): cached state, like the
    # stage, written only by Admissions::ApplicantChanges with its event.
    add_column :admissions_applicants, :emails_paused, :boolean, null: false, default: false

    reversible do |dir|
      dir.up { execute GUARDS }
      dir.down { execute DROP_GUARDS }
    end
  end

  # - The pause switch joins the applicant columns that change only inside
  #   Admissions::ApplicantChanges (admissions.service_write on).
  # - Outbox rows are written only with admissions.service_write on, and are
  #   never deleted or truncated. Once sent or discarded an email does not
  #   change, except that withdrawal blanks its text and address.
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
            NEW.emails_paused, NEW.email, NEW.phone, NEW.name)
           IS DISTINCT FROM
           (OLD.stage, OLD.stage_entered_at, OLD.held_from_stage, OLD.hold_reason, OLD.hold_until,
            OLD.exited_from_stage, OLD.complicated, OLD.complicated_note, OLD.complicated_check_back_on,
            OLD.emails_paused, OLD.email, OLD.phone, OLD.name) THEN
          RAISE EXCEPTION 'admissions applicant state and contact details change only through Admissions::ApplicantChanges';
        END IF;
      END IF;
      RETURN NEW;
    END
    $$;

    CREATE OR REPLACE FUNCTION admissions_emails_guard() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      IF TG_OP = 'DELETE' OR TG_OP = 'TRUNCATE' THEN
        RAISE EXCEPTION 'admissions emails are never deleted';
      END IF;
      IF current_setting('admissions.service_write', true) IS DISTINCT FROM 'on' THEN
        RAISE EXCEPTION 'admissions emails are written only through Admissions::EmailSender';
      END IF;
      IF TG_OP = 'UPDATE' AND OLD.status <> 'held'
         AND NOT (NEW.subject IS NULL AND NEW.body IS NULL AND NEW.to_address IS NULL
                  AND NEW.redacted_at IS NOT NULL
                  AND (NEW.id, NEW.applicant_id, NEW.email_type, NEW.status,
                       NEW.drafted_by_type, NEW.drafted_by_user_id, NEW.drafted_at,
                       NEW.edited_by_type, NEW.edited_by_user_id, NEW.edited_at,
                       NEW.sent_by_type, NEW.sent_by_user_id, NEW.sent_at,
                       NEW.delivery, NEW.delivery_message_id,
                       NEW.discarded_by_type, NEW.discarded_by_user_id, NEW.discarded_at)
                      IS NOT DISTINCT FROM
                      (OLD.id, OLD.applicant_id, OLD.email_type, OLD.status,
                       OLD.drafted_by_type, OLD.drafted_by_user_id, OLD.drafted_at,
                       OLD.edited_by_type, OLD.edited_by_user_id, OLD.edited_at,
                       OLD.sent_by_type, OLD.sent_by_user_id, OLD.sent_at,
                       OLD.delivery, OLD.delivery_message_id,
                       OLD.discarded_by_type, OLD.discarded_by_user_id, OLD.discarded_at)) THEN
        RAISE EXCEPTION 'a sent or discarded admissions email does not change';
      END IF;
      RETURN NEW;
    END
    $$;

    CREATE TRIGGER admissions_emails_guard
      BEFORE INSERT OR UPDATE OR DELETE ON admissions_emails
      FOR EACH ROW EXECUTE FUNCTION admissions_emails_guard();

    CREATE TRIGGER admissions_emails_no_truncate
      BEFORE TRUNCATE ON admissions_emails
      FOR EACH STATEMENT EXECUTE FUNCTION admissions_emails_guard();
  SQL

  DROP_GUARDS = <<~SQL.freeze
    DROP TRIGGER IF EXISTS admissions_emails_no_truncate ON admissions_emails;
    DROP TRIGGER IF EXISTS admissions_emails_guard ON admissions_emails;
    DROP FUNCTION IF EXISTS admissions_emails_guard();

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
  SQL
end
