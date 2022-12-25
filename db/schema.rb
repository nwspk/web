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

ActiveRecord::Schema[7.0].define(version: 2017_01_09_174216) do
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

  create_table "addresses", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "recipient"
    t.string "street"
    t.string "city"
    t.string "postal_code"
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["user_id"], name: "index_addresses_on_user_id"
  end

  create_table "connections", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "provider", default: "", null: false
    t.string "uid", default: "", null: false
    t.string "access_token", default: "", null: false
    t.string "secret"
    t.datetime "expires_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "profile_url"
    t.string "username", default: "", null: false
    t.index ["provider", "uid"], name: "index_connections_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_connections_on_user_id"
  end

  create_table "door_accesses", id: :serial, force: :cascade do |t|
    t.integer "ring_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["ring_id"], name: "index_door_accesses_on_ring_id"
    t.index ["user_id"], name: "index_door_accesses_on_user_id"
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
    t.string "gcal_id"
    t.index ["end_at"], name: "index_events_on_end_at"
    t.index ["start_at"], name: "index_events_on_start_at"
  end

  create_table "friend_edges", id: :serial, force: :cascade do |t|
    t.integer "from_id", null: false
    t.integer "to_id", null: false
    t.string "network", default: "", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["from_id"], name: "index_friend_edges_on_from_id"
    t.index ["to_id"], name: "index_friend_edges_on_to_id"
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
    t.float "contribution", default: 0.0, null: false
  end

  create_table "rings", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "uid", default: "", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["user_id"], name: "index_rings_on_user_id"
  end

  create_table "staff_reminders", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "string", default: "", null: false
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
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "role", default: "", null: false
    t.boolean "showcase", default: false, null: false
    t.string "url", default: "", null: false
    t.float "ring_size"
    t.string "showcase_text", default: "", null: false
    t.text "application_text", default: "", null: false
    t.text "notes"
    t.string "avatar"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

end
