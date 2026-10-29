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

ActiveRecord::Schema[8.1].define(version: 2026_10_29_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "articles", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.integer "kind", default: 0, null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((title)::text) gin_trgm_ops", name: "index_articles_on_title_trigram", using: :gin
    t.index ["author_id"], name: "index_articles_on_author_id"
    t.index ["kind", "published_at"], name: "index_articles_on_kind_and_published_at"
    t.index ["published_at"], name: "index_articles_on_published_at"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text) gin_trgm_ops", name: "index_categories_on_name_trigram", using: :gin
    t.index ["active", "position"], name: "index_categories_on_active_and_position"
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "feature_flags", force: :cascade do |t|
    t.string "key", null: false
    t.boolean "enabled", default: false, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_feature_flags_on_key", unique: true
    t.check_constraint "key::text ~ '^[a-z][a-z0-9_]*$'::text", name: "feature_flags_key_format"
  end

  create_table "firms", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "owner_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "phone"
    t.string "whatsapp"
    t.string "address"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "working_hours"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((address)::text) gin_trgm_ops", name: "index_firms_on_address_trigram", using: :gin
    t.index "lower((name)::text) gin_trgm_ops", name: "index_firms_on_name_trigram", using: :gin
    t.index "lower((phone)::text) gin_trgm_ops", name: "index_firms_on_phone_trigram", using: :gin
    t.index ["category_id", "status"], name: "index_firms_on_category_id_and_status"
    t.index ["category_id"], name: "index_firms_on_category_id"
    t.index ["owner_id"], name: "index_firms_on_owner_id"
    t.index ["status"], name: "index_firms_on_status"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "kind", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "read_at"
    t.string "dedupe_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dedupe_key"], name: "index_notifications_on_dedupe_key", unique: true, where: "(dedupe_key IS NOT NULL)"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_notifications_unread_by_user", where: "(read_at IS NULL)"
  end

  create_table "stored_files", force: :cascade do |t|
    t.string "key", null: false
    t.binary "data", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_stored_files_on_key", unique: true
  end

  create_table "subscription_plans", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "price_cents", null: false
    t.integer "duration_days", null: false
    t.integer "max_firms", default: 1, null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text) gin_trgm_ops", name: "index_subscription_plans_on_name_trigram", using: :gin
    t.index ["name"], name: "index_subscription_plans_on_name", unique: true
    t.check_constraint "duration_days > 0", name: "subscription_plans_duration_positive"
    t.check_constraint "max_firms > 0", name: "subscription_plans_max_firms_positive"
    t.check_constraint "price_cents >= 0", name: "subscription_plans_price_non_negative"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "subscription_plan_id", null: false
    t.bigint "reviewed_by_id"
    t.integer "status", default: 0, null: false
    t.integer "payment_method", null: false
    t.integer "amount_cents", null: false
    t.string "transaction_reference", null: false
    t.string "payer_phone"
    t.text "notes"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "reviewed_at"
    t.text "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((payer_phone)::text) gin_trgm_ops", name: "index_subscriptions_on_payer_phone_trigram", using: :gin
    t.index "lower((transaction_reference)::text) gin_trgm_ops", name: "index_subscriptions_on_transaction_reference_trigram", using: :gin
    t.index ["payment_method", "transaction_reference"], name: "index_subscriptions_on_payment_reference", unique: true
    t.index ["reviewed_by_id"], name: "index_subscriptions_on_reviewed_by_id"
    t.index ["status", "ends_at"], name: "index_subscriptions_on_status_and_ends_at"
    t.index ["subscription_plan_id"], name: "index_subscriptions_on_subscription_plan_id"
    t.index ["user_id", "status", "ends_at"], name: "index_subscriptions_on_user_id_and_status_and_ends_at"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
    t.index ["user_id"], name: "index_subscriptions_one_pending_per_user", unique: true, where: "(status = 0)"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "phone", null: false
    t.string "email"
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index "lower((email)::text) gin_trgm_ops", name: "index_users_on_email_trigram", using: :gin
    t.index "lower((name)::text) gin_trgm_ops", name: "index_users_on_name_trigram", using: :gin
    t.index "lower((phone)::text) gin_trgm_ops", name: "index_users_on_phone_trigram", using: :gin
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["phone"], name: "index_users_on_phone", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "articles", "users", column: "author_id"
  add_foreign_key "firms", "categories"
  add_foreign_key "firms", "users", column: "owner_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "subscriptions", "subscription_plans"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "subscriptions", "users", column: "reviewed_by_id"
end
