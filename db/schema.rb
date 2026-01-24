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

ActiveRecord::Schema[8.0].define(version: 2026_01_24_100001) do
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

  create_table "affiliate_clicks", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.datetime "clicked_at", null: false
    t.string "ip_hash"
    t.string "user_agent"
    t.text "referrer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clicked_at"], name: "index_affiliate_clicks_on_clicked_at"
    t.index ["listing_id", "clicked_at"], name: "index_affiliate_clicks_on_listing_clicked"
    t.index ["listing_id"], name: "index_affiliate_clicks_on_listing_id"
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

  create_table "comments", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.bigint "user_id", null: false
    t.bigint "content_item_id", null: false
    t.bigint "parent_id"
    t.text "body", null: false
    t.datetime "edited_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_item_id", "parent_id"], name: "index_comments_on_content_item_and_parent"
    t.index ["content_item_id"], name: "index_comments_on_content_item_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["site_id", "user_id"], name: "index_comments_on_site_and_user"
    t.index ["site_id"], name: "index_comments_on_site_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
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
    t.jsonb "topic_tags", default: [], null: false
    t.string "content_type"
    t.decimal "tagging_confidence", precision: 3, scale: 2
    t.jsonb "tagging_explanation", default: [], null: false
    t.text "ai_summary"
    t.text "why_it_matters"
    t.jsonb "ai_suggested_tags", default: [], null: false
    t.datetime "editorialised_at"
    t.integer "upvotes_count", default: 0, null: false
    t.integer "comments_count", default: 0, null: false
    t.datetime "hidden_at"
    t.bigint "hidden_by_id"
    t.datetime "comments_locked_at"
    t.bigint "comments_locked_by_id"
    t.index ["comments_locked_by_id"], name: "index_content_items_on_comments_locked_by_id"
    t.index ["hidden_at"], name: "index_content_items_on_hidden_at"
    t.index ["hidden_by_id"], name: "index_content_items_on_hidden_by_id"
    t.index ["published_at"], name: "index_content_items_on_published_at"
    t.index ["site_id", "content_type"], name: "index_content_items_on_site_id_and_content_type"
    t.index ["site_id", "editorialised_at"], name: "index_content_items_on_site_id_and_editorialised_at"
    t.index ["site_id", "published_at"], name: "index_content_items_on_site_id_published_at_desc", order: { published_at: :desc }
    t.index ["site_id", "url_canonical"], name: "index_content_items_on_site_id_and_url_canonical", unique: true
    t.index ["site_id"], name: "index_content_items_on_site_id"
    t.index ["source_id", "created_at"], name: "index_content_items_on_source_id_and_created_at"
    t.index ["source_id"], name: "index_content_items_on_source_id"
    t.index ["topic_tags"], name: "index_content_items_on_topic_tags_gin", using: :gin
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

  create_table "editorialisations", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.bigint "content_item_id", null: false
    t.string "prompt_version", null: false
    t.text "prompt_text", null: false
    t.text "raw_response"
    t.jsonb "parsed_response", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.text "error_message"
    t.integer "tokens_used"
    t.string "ai_model"
    t.integer "duration_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_item_id"], name: "index_editorialisations_on_content_item_id", unique: true
    t.index ["site_id", "created_at"], name: "index_editorialisations_on_site_id_and_created_at"
    t.index ["site_id", "status"], name: "index_editorialisations_on_site_id_and_status"
    t.index ["site_id"], name: "index_editorialisations_on_site_id"
  end

  create_table "flags", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.bigint "user_id", null: false
    t.string "flaggable_type", null: false
    t.bigint "flaggable_id", null: false
    t.integer "reason", default: 0, null: false
    t.text "details"
    t.integer "status", default: 0, null: false
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flaggable_type", "flaggable_id"], name: "index_flags_on_flaggable"
    t.index ["reviewed_by_id"], name: "index_flags_on_reviewed_by_id"
    t.index ["site_id", "status"], name: "index_flags_on_site_and_status"
    t.index ["site_id", "user_id", "flaggable_type", "flaggable_id"], name: "index_flags_uniqueness", unique: true
    t.index ["site_id"], name: "index_flags_on_site_id"
    t.index ["user_id"], name: "index_flags_on_user_id"
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
    t.integer "listing_type", default: 0, null: false
    t.text "affiliate_url_template"
    t.jsonb "affiliate_attribution", default: {}, null: false
    t.datetime "featured_from"
    t.datetime "featured_until"
    t.bigint "featured_by_id"
    t.string "company"
    t.string "location"
    t.string "salary_range"
    t.text "apply_url"
    t.datetime "expires_at"
    t.boolean "paid", default: false, null: false
    t.string "payment_reference"
    t.index ["category_id", "published_at"], name: "index_listings_on_category_published"
    t.index ["category_id"], name: "index_listings_on_category_id"
    t.index ["domain"], name: "index_listings_on_domain"
    t.index ["featured_by_id"], name: "index_listings_on_featured_by_id"
    t.index ["published_at"], name: "index_listings_on_published_at"
    t.index ["site_id", "expires_at"], name: "index_listings_on_site_expires_at"
    t.index ["site_id", "featured_from", "featured_until"], name: "index_listings_on_site_featured_dates"
    t.index ["site_id", "listing_type", "expires_at"], name: "index_listings_on_site_type_expires"
    t.index ["site_id", "listing_type"], name: "index_listings_on_site_listing_type"
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

  create_table "site_bans", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.bigint "user_id", null: false
    t.bigint "banned_by_id", null: false
    t.text "reason"
    t.datetime "banned_at", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["banned_by_id"], name: "index_site_bans_on_banned_by_id"
    t.index ["site_id", "expires_at"], name: "index_site_bans_on_site_and_expires"
    t.index ["site_id", "user_id"], name: "index_site_bans_uniqueness", unique: true
    t.index ["site_id"], name: "index_site_bans_on_site_id"
    t.index ["user_id"], name: "index_site_bans_on_user_id"
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
    t.decimal "quality_weight", precision: 3, scale: 2, default: "1.0", null: false
    t.index ["site_id", "name"], name: "index_sources_on_site_id_and_name", unique: true
    t.index ["site_id"], name: "index_sources_on_site_id"
    t.index ["tenant_id", "enabled"], name: "index_sources_on_tenant_id_and_enabled"
    t.index ["tenant_id", "kind"], name: "index_sources_on_tenant_id_and_kind"
    t.index ["tenant_id", "name"], name: "index_sources_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_sources_on_tenant_id"
  end

  create_table "tagging_rules", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.bigint "tenant_id", null: false
    t.bigint "taxonomy_id", null: false
    t.integer "rule_type", null: false
    t.text "pattern", null: false
    t.integer "priority", default: 100, null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "enabled"], name: "index_tagging_rules_on_site_id_and_enabled"
    t.index ["site_id", "priority"], name: "index_tagging_rules_on_site_id_and_priority"
    t.index ["site_id"], name: "index_tagging_rules_on_site_id"
    t.index ["taxonomy_id"], name: "index_tagging_rules_on_taxonomy_id"
    t.index ["tenant_id"], name: "index_tagging_rules_on_tenant_id"
  end

  create_table "taxonomies", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "parent_id"], name: "index_taxonomies_on_site_id_and_parent_id"
    t.index ["site_id", "slug"], name: "index_taxonomies_on_site_id_and_slug", unique: true
    t.index ["site_id"], name: "index_taxonomies_on_site_id"
    t.index ["tenant_id"], name: "index_taxonomies_on_tenant_id"
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

  create_table "votes", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.bigint "user_id", null: false
    t.bigint "content_item_id", null: false
    t.integer "value", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_item_id"], name: "index_votes_on_content_item_id"
    t.index ["site_id", "user_id", "content_item_id"], name: "index_votes_uniqueness", unique: true
    t.index ["site_id"], name: "index_votes_on_site_id"
    t.index ["user_id"], name: "index_votes_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "affiliate_clicks", "listings"
  add_foreign_key "categories", "sites"
  add_foreign_key "categories", "tenants"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "content_items"
  add_foreign_key "comments", "sites"
  add_foreign_key "comments", "users"
  add_foreign_key "content_items", "sites"
  add_foreign_key "content_items", "sources"
  add_foreign_key "content_items", "users", column: "comments_locked_by_id"
  add_foreign_key "content_items", "users", column: "hidden_by_id"
  add_foreign_key "domains", "sites"
  add_foreign_key "editorialisations", "content_items"
  add_foreign_key "editorialisations", "sites"
  add_foreign_key "flags", "sites"
  add_foreign_key "flags", "users"
  add_foreign_key "flags", "users", column: "reviewed_by_id"
  add_foreign_key "import_runs", "sites"
  add_foreign_key "import_runs", "sources"
  add_foreign_key "listings", "categories"
  add_foreign_key "listings", "sites"
  add_foreign_key "listings", "sources"
  add_foreign_key "listings", "tenants"
  add_foreign_key "listings", "users", column: "featured_by_id"
  add_foreign_key "site_bans", "sites"
  add_foreign_key "site_bans", "users"
  add_foreign_key "site_bans", "users", column: "banned_by_id"
  add_foreign_key "sites", "tenants"
  add_foreign_key "sources", "sites"
  add_foreign_key "sources", "tenants"
  add_foreign_key "tagging_rules", "sites"
  add_foreign_key "tagging_rules", "taxonomies"
  add_foreign_key "tagging_rules", "tenants"
  add_foreign_key "taxonomies", "sites"
  add_foreign_key "taxonomies", "taxonomies", column: "parent_id"
  add_foreign_key "taxonomies", "tenants"
  add_foreign_key "votes", "content_items"
  add_foreign_key "votes", "sites"
  add_foreign_key "votes", "users"
end
