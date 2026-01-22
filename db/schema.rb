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

ActiveRecord::Schema[8.0].define(version: 2026_01_20_215433) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "categories", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "site_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.boolean "allow_paths", default: true, null: false
    t.jsonb "shown_fields", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "key"], name: "index_categories_on_site_id_and_key", unique: true
    t.index ["site_id", "name"], name: "index_categories_on_site_id_and_name"
    t.index ["site_id"], name: "index_categories_on_site_id"
    t.index ["tenant_id", "key"], name: "index_categories_on_tenant_id_and_key", unique: true
    t.index ["tenant_id", "name"], name: "index_categories_on_tenant_name"
    t.index ["tenant_id"], name: "index_categories_on_tenant_id"
  end

  create_table "content_items", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.bigint "source_id", null: false
    t.string "url_canonical", null: false
    t.text "url_raw", null: false
    t.string "title"
    t.text "description"
    t.text "extracted_text"
    t.jsonb "raw_payload", default: {}, null: false
    t.jsonb "tags", default: [], null: false
    t.text "summary"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_content_items_on_published_at"
    t.index ["site_id", "url_canonical"], name: "index_content_items_on_site_id_and_url_canonical", unique: true
    t.index ["site_id"], name: "index_content_items_on_site_id"
    t.index ["source_id", "created_at"], name: "index_content_items_on_source_id_and_created_at"
    t.index ["source_id"], name: "index_content_items_on_source_id"
  end

  create_table "domains", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.string "hostname", null: false
    t.boolean "verified", default: false, null: false
    t.datetime "verified_at"
    t.boolean "primary", default: false, null: false
    t.integer "status", default: 0, null: false
    t.datetime "last_checked_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hostname"], name: "index_domains_on_hostname", unique: true
    t.index ["site_id", "verified"], name: "index_domains_on_site_id_and_verified"
    t.index ["site_id"], name: "index_domains_on_site_id"
    t.index ["site_id"], name: "index_domains_on_site_id_where_primary", unique: true, where: "(\"primary\" = true)"
    t.index ["status"], name: "index_domains_on_status"
  end

  create_table "heartbeat_logs", force: :cascade do |t|
    t.datetime "executed_at", null: false
    t.string "environment", null: false
    t.string "hostname", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["environment", "executed_at"], name: "index_heartbeat_logs_on_environment_and_executed_at"
    t.index ["executed_at"], name: "index_heartbeat_logs_on_executed_at"
  end

  create_table "import_runs", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.bigint "source_id", null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.integer "status", default: 0, null: false
    t.text "error_message"
    t.integer "items_count", default: 0
    t.integer "items_created", default: 0
    t.integer "items_updated", default: 0
    t.integer "items_failed", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "started_at"], name: "index_import_runs_on_site_id_and_started_at"
    t.index ["site_id"], name: "index_import_runs_on_site_id"
    t.index ["source_id", "started_at"], name: "index_import_runs_on_source_id_and_started_at"
    t.index ["source_id"], name: "index_import_runs_on_source_id"
    t.index ["status"], name: "index_import_runs_on_status"
  end

  create_table "listings", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "site_id", null: false
    t.bigint "category_id", null: false
    t.bigint "source_id"
    t.text "url_raw", null: false
    t.text "url_canonical", null: false
    t.string "domain"
    t.string "title"
    t.text "description"
    t.text "image_url"
    t.string "site_name"
    t.datetime "published_at"
    t.text "body_html"
    t.text "body_text"
    t.jsonb "ai_summaries", default: {}, null: false
    t.jsonb "ai_tags", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "published_at"], name: "index_listings_on_category_published"
    t.index ["category_id"], name: "index_listings_on_category_id"
    t.index ["domain"], name: "index_listings_on_domain"
    t.index ["published_at"], name: "index_listings_on_published_at"
    t.index ["site_id", "url_canonical"], name: "index_listings_on_site_id_and_url_canonical", unique: true
    t.index ["site_id"], name: "index_listings_on_site_id"
    t.index ["source_id"], name: "index_listings_on_source_id"
    t.index ["tenant_id", "category_id"], name: "index_listings_on_tenant_id_and_category_id"
    t.index ["tenant_id", "domain", "published_at"], name: "index_listings_on_tenant_domain_published"
    t.index ["tenant_id", "published_at", "created_at"], name: "index_listings_on_tenant_published_created"
    t.index ["tenant_id", "source_id"], name: "index_listings_on_tenant_id_and_source_id"
    t.index ["tenant_id", "title"], name: "index_listings_on_tenant_title"
    t.index ["tenant_id", "url_canonical"], name: "index_listings_on_tenant_and_url_canonical", unique: true
    t.index ["tenant_id"], name: "index_listings_on_tenant_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.string "resource_type"
    t.bigint "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource"
  end

  create_table "sites", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "slug", null: false
    t.string "name", null: false
    t.text "description"
    t.jsonb "config", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_sites_on_status"
    t.index ["tenant_id", "slug"], name: "index_sites_on_tenant_id_and_slug", unique: true
    t.index ["tenant_id", "status"], name: "index_sites_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_sites_on_tenant_id"
  end

  create_table "sources", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "site_id", null: false
    t.integer "kind", null: false
    t.string "name", null: false
    t.jsonb "config", default: {}, null: false
    t.jsonb "schedule", default: {}, null: false
    t.datetime "last_run_at"
    t.string "last_status"
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "name"], name: "index_sources_on_site_id_and_name", unique: true
    t.index ["site_id"], name: "index_sources_on_site_id"
    t.index ["tenant_id", "enabled"], name: "index_sources_on_tenant_id_and_enabled"
    t.index ["tenant_id", "kind"], name: "index_sources_on_tenant_id_and_kind"
    t.index ["tenant_id", "name"], name: "index_sources_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_sources_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "hostname", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.text "description"
    t.string "logo_url"
    t.jsonb "settings", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hostname"], name: "index_tenants_on_hostname", unique: true
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
    t.index ["status", "hostname"], name: "index_tenants_on_status_hostname"
    t.index ["status"], name: "index_tenants_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "role_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "sites"
  add_foreign_key "categories", "tenants"
  add_foreign_key "content_items", "sites"
  add_foreign_key "content_items", "sources"
  add_foreign_key "domains", "sites"
  add_foreign_key "import_runs", "sites"
  add_foreign_key "import_runs", "sources"
  add_foreign_key "listings", "categories"
  add_foreign_key "listings", "sites"
  add_foreign_key "listings", "sources"
  add_foreign_key "listings", "tenants"
  add_foreign_key "sites", "tenants"
  add_foreign_key "sources", "sites"
  add_foreign_key "sources", "tenants"
end
