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

ActiveRecord::Schema[8.1].define(version: 2026_05_19_220000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "price_refresh_runs", force: :cascade do |t|
    t.integer "attempted", default: 0, null: false
    t.integer "batch_size"
    t.integer "batches_run", default: 1, null: false
    t.integer "catalog_with_url"
    t.datetime "created_at", null: false
    t.decimal "duration_seconds", precision: 8, scale: 1
    t.datetime "enqueued_at", null: false
    t.text "error_message"
    t.integer "failed", default: 0, null: false
    t.jsonb "failure_details", default: [], null: false
    t.datetime "finished_at"
    t.datetime "started_at"
    t.integer "stale_remaining"
    t.string "status", default: "pending", null: false
    t.integer "succeeded", default: 0, null: false
    t.integer "total_products"
    t.string "triggered_by", default: "unknown", null: false
    t.datetime "updated_at", null: false
    t.index ["enqueued_at"], name: "index_price_refresh_runs_on_enqueued_at"
    t.index ["status"], name: "index_price_refresh_runs_on_status"
  end

  create_table "price_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.decimal "price", null: false
    t.bigint "product_id", null: false
    t.datetime "recorded_at", null: false
    t.string "source", default: "manual", null: false
    t.string "store_name", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["product_id"], name: "index_price_records_on_product_id"
    t.index ["recorded_at"], name: "index_price_records_on_recorded_at"
    t.index ["source"], name: "index_price_records_on_source"
    t.check_constraint "char_length(store_name::text) <= 120", name: "price_records_store_name_length"
    t.check_constraint "notes IS NULL OR char_length(notes) <= 1000", name: "price_records_notes_length"
    t.check_constraint "price > 0::numeric", name: "price_records_price_positive"
    t.check_constraint "url IS NULL OR char_length(url::text) <= 2000", name: "price_records_url_length"
  end

  create_table "products", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "image_url"
    t.datetime "last_alerted_at"
    t.string "last_fetch_error"
    t.datetime "last_fetched_at"
    t.string "name", null: false
    t.string "source_url"
    t.decimal "target_price", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["category"], name: "index_products_on_category"
    t.index ["created_at"], name: "index_products_on_created_at"
    t.index ["source_url"], name: "index_products_on_source_url"
    t.index ["user_id"], name: "index_products_on_user_id"
    t.check_constraint "char_length(category::text) <= 80", name: "products_category_length"
    t.check_constraint "char_length(name::text) <= 140", name: "products_name_length"
    t.check_constraint "description IS NULL OR char_length(description) <= 1000", name: "products_description_length"
    t.check_constraint "image_url IS NULL OR char_length(image_url::text) <= 2000", name: "products_image_url_length"
    t.check_constraint "source_url IS NULL OR char_length(source_url::text) <= 2000", name: "products_source_url_length"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.string "provider"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "price_records", "products"
  add_foreign_key "products", "users"
  add_foreign_key "sessions", "users"
end
