# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150503111328) do

  create_table "active_admin_comments", force: :cascade do |t|
    t.string   "namespace"
    t.text     "body"
    t.string   "resource_id",   null: false
    t.string   "resource_type", null: false
    t.integer  "author_id"
    t.string   "author_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "active_admin_comments", ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
  add_index "active_admin_comments", ["namespace"], name: "index_active_admin_comments_on_namespace"
  add_index "active_admin_comments", ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"

  create_table "addresses", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "recipient"
    t.string   "street"
    t.string   "city"
    t.string   "postal_code"
    t.string   "country"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "connections", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "provider",     default: "", null: false
    t.string   "uid",          default: "", null: false
    t.string   "access_token", default: "", null: false
    t.string   "secret"
    t.datetime "expires_at"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "profile_url"
  end

  add_index "connections", ["provider", "uid"], name: "index_connections_on_provider_and_uid", unique: true
  add_index "connections", ["user_id"], name: "index_connections_on_user_id"

  create_table "door_accesses", force: :cascade do |t|
    t.integer  "ring_id",    null: false
    t.integer  "user_id",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "door_accesses", ["ring_id"], name: "index_door_accesses_on_ring_id"
  add_index "door_accesses", ["user_id"], name: "index_door_accesses_on_user_id"

  create_table "friend_edges", force: :cascade do |t|
    t.integer  "from_id"
    t.integer  "to_id"
    t.string   "network",    default: "", null: false
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "friend_edges", ["from_id"], name: "index_friend_edges_on_from_id"
  add_index "friend_edges", ["to_id"], name: "index_friend_edges_on_to_id"

  create_table "payments", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "total"
    t.string   "stripe_invoice_id", default: "", null: false
    t.datetime "date"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "payments", ["user_id"], name: "index_payments_on_user_id"

  create_table "plans", force: :cascade do |t|
    t.string   "name",       default: "",   null: false
    t.string   "stripe_id",  default: "",   null: false
    t.integer  "value",      default: 0,    null: false
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.boolean  "visible",    default: true, null: false
  end

  create_table "rings", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "uid",        default: "", null: false
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "rings", ["user_id"], name: "index_rings_on_user_id"

  create_table "subscriptions", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "customer_id",     default: "", null: false
    t.string   "subscription_id", default: "", null: false
    t.integer  "plan_id"
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.datetime "active_until"
  end

  add_index "subscriptions", ["plan_id"], name: "index_subscriptions_on_plan_id"

  create_table "users", force: :cascade do |t|
    t.string   "name",                   default: "",    null: false
    t.string   "email",                  default: "",    null: false
    t.string   "encrypted_password",     default: "",    null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,     null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "role",                   default: "",    null: false
    t.boolean  "showcase",               default: false, null: false
    t.string   "url",                    default: "",    null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true

end
