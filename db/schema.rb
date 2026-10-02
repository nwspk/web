# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_10_02_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_admin_comments", id: :serial, force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_id", null: false
    t.string "resource_type", null: false
    t.string "author_type"
    t.integer "author_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"
  end

  create_table "admissions_applicant_events", force: :cascade do |t|
    t.bigint "applicant_id", null: false
    t.string "kind", null: false
    t.string "actor_type", null: false
    t.bigint "actor_user_id"
    t.string "from_stage"
    t.string "to_stage"
    t.jsonb "details", default: {}, null: false
    t.text "body"
    t.datetime "redacted_at"
    t.datetime "created_at", null: false
    t.index ["actor_user_id"], name: "index_admissions_applicant_events_on_actor_user_id"
    t.index ["applicant_id"], name: "index_admissions_applicant_events_on_applicant_id"
    t.index ["kind"], name: "index_admissions_applicant_events_on_kind"
  end

  create_table "admissions_applicants", force: :cascade do |t|
    t.bigint "round_id", null: false
    t.bigint "previous_applicant_id"
    t.string "email"
    t.string "phone"
    t.string "name"
    t.string "stage", null: false
    t.datetime "stage_entered_at", null: false
    t.string "held_from_stage"
    t.text "hold_reason"
    t.date "hold_until"
    t.string "exited_from_stage"
    t.boolean "complicated", default: false, null: false
    t.text "complicated_note"
    t.date "complicated_check_back_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "round_id, lower((email)::text)", name: "index_admissions_applicants_on_round_and_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["previous_applicant_id"], name: "index_admissions_applicants_on_previous_applicant_id"
    t.index ["round_id"], name: "index_admissions_applicants_on_round_id"
    t.index ["stage"], name: "index_admissions_applicants_on_stage"
  end

  create_table "admissions_rounds", force: :cascade do |t|
    t.string "name", null: false
    t.date "opens_on"
    t.date "invites_on"
    t.date "closes_on"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_admissions_rounds_on_name", unique: true
  end

  create_table "admissions_staff_members", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_admissions_staff_members_on_user_id", unique: true
  end

  create_table "events", id: :serial, force: :cascade do |t|
    t.string "name", default: "", null: false
    t.datetime "start_at", precision: nil, null: false
    t.datetime "end_at", precision: nil, null: false
    t.string "url", default: "", null: false
    t.text "location", null: false
    t.string "organiser_name", default: "", null: false
    t.string "organiser_email", default: "", null: false
    t.string "organiser_url", default: "", null: false
    t.text "description", null: false
    t.boolean "public", null: false
    t.integer "status"
    t.integer "value"
    t.text "notes", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "short_description", default: "", null: false
    t.index ["end_at"], name: "index_events_on_end_at"
    t.index ["start_at"], name: "index_events_on_start_at"
  end

  create_table "payments", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "total"
    t.string "stripe_invoice_id", default: "", null: false
    t.datetime "date", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "plan_id"
    t.index ["plan_id"], name: "index_payments_on_plan_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "plans", id: :serial, force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "stripe_id", default: "", null: false
    t.integer "value", default: 0, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "visible", default: true, null: false
  end

  create_table "staff_reminders", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.integer "frequency"
    t.integer "last_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "last_run_at", precision: nil
    t.boolean "active"
  end

  create_table "subscriptions", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "customer_id", default: "", null: false
    t.string "subscription_id", default: "", null: false
    t.integer "plan_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "active_until", precision: nil
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "role", default: "", null: false
    t.boolean "showcase", default: false, null: false
    t.string "url", default: "", null: false
    t.string "showcase_text", default: "", null: false
    t.text "application_text", default: "", null: false
    t.text "notes"
    t.string "avatar"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "admissions_applicant_events", "admissions_applicants", column: "applicant_id"
  add_foreign_key "admissions_applicant_events", "users", column: "actor_user_id"
  add_foreign_key "admissions_applicants", "admissions_applicants", column: "previous_applicant_id"
  add_foreign_key "admissions_applicants", "admissions_rounds", column: "round_id"
  add_foreign_key "admissions_staff_members", "users", on_delete: :cascade
end
