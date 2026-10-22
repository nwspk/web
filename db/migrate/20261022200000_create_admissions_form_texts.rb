# admit phase 1b: the eoi-form's own wording (spec: nwspk/admit SPEC.md §2
# eoi-form, §9, §9b; BUILD-PLAN checklist item 4).
#
# The form's introduction and its privacy notice are Ed's words, so they
# live in the database, never in this public repository. Each edit is a new
# row: the current text is the latest row for its key, and the rows before
# it are the log of who changed it, when, and to what. Rows are never
# changed or deleted, so the notice an applicant saw can always be read
# back (their `created` event names it).
class CreateAdmissionsFormTexts < ActiveRecord::Migration[7.2]
  def change
    create_table :admissions_form_texts do |t|
      t.string :key, null: false
      t.text :body, null: false
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false

      t.check_constraint "key IN ('eoi_introduction', 'privacy_notice')", name: 'admissions_form_texts_key'
    end
    add_index :admissions_form_texts, %i[key id]

    reversible do |dir|
      dir.up { execute GUARDS }
      dir.down { execute DROP_GUARDS }
    end
  end

  GUARDS = <<~SQL.freeze
    CREATE OR REPLACE FUNCTION admissions_form_texts_append_only() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      RAISE EXCEPTION 'admissions form texts are append-only: save a new version instead';
    END
    $$;

    CREATE TRIGGER admissions_form_texts_append_only
      BEFORE UPDATE OR DELETE ON admissions_form_texts
      FOR EACH ROW EXECUTE FUNCTION admissions_form_texts_append_only();

    CREATE TRIGGER admissions_form_texts_no_truncate
      BEFORE TRUNCATE ON admissions_form_texts
      FOR EACH STATEMENT EXECUTE FUNCTION admissions_form_texts_append_only();
  SQL

  DROP_GUARDS = <<~SQL.freeze
    DROP TRIGGER IF EXISTS admissions_form_texts_no_truncate ON admissions_form_texts;
    DROP TRIGGER IF EXISTS admissions_form_texts_append_only ON admissions_form_texts;
    DROP FUNCTION IF EXISTS admissions_form_texts_append_only();
  SQL
end
