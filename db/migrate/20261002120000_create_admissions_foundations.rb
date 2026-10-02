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
  end
end
