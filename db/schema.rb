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

ActiveRecord::Schema[8.1].define(version: 2026_02_08_185840) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "affiliate_clicks", force: :cascade do |t|
    t.datetime "clicked_at", null: false
    t.datetime "created_at", null: false
    t.string "ip_hash"
    t.bigint "listing_id", null: false
    t.text "referrer"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["clicked_at"], name: "index_affiliate_clicks_on_clicked_at"
    t.index ["listing_id", "clicked_at"], name: "index_affiliate_clicks_on_listing_clicked"
    t.index ["listing_id"], name: "index_affiliate_clicks_on_listing_id"
  end

  create_table "bookmarks", force: :cascade do |t|
    t.bigint "bookmarkable_id", null: false
    t.string "bookmarkable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["bookmarkable_type", "bookmarkable_id"], name: "index_bookmarks_on_bookmarkable"
    t.index ["user_id", "bookmarkable_type", "bookmarkable_id"], name: "index_bookmarks_uniqueness", unique: true
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "boost_clicks", force: :cascade do |t|
    t.datetime "clicked_at", null: false
    t.datetime "converted_at"
    t.datetime "created_at", null: false
    t.bigint "digest_subscription_id"
    t.decimal "earned_amount", precision: 8, scale: 2
    t.string "ip_hash"
    t.bigint "network_boost_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["digest_subscription_id"], name: "index_boost_clicks_on_digest_subscription_id"
    t.index ["ip_hash", "clicked_at"], name: "index_boost_clicks_on_ip_hash_and_clicked_at"
    t.index ["network_boost_id", "clicked_at"], name: "index_boost_clicks_on_network_boost_id_and_clicked_at"
    t.index ["network_boost_id"], name: "index_boost_clicks_on_network_boost_id"
    t.index ["status"], name: "index_boost_clicks_on_status"
  end

  create_table "boost_impressions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_hash"
    t.bigint "network_boost_id", null: false
    t.datetime "shown_at", null: false
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["network_boost_id", "shown_at"], name: "index_boost_impressions_on_network_boost_id_and_shown_at"
    t.index ["network_boost_id"], name: "index_boost_impressions_on_network_boost_id"
    t.index ["site_id", "shown_at"], name: "index_boost_impressions_on_site_id_and_shown_at"
    t.index ["site_id"], name: "index_boost_impressions_on_site_id"
  end

  create_table "boost_payouts", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "paid_at"
    t.string "payment_reference"
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.bigint "site_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "period_start"], name: "index_boost_payouts_on_site_id_and_period_start"
    t.index ["site_id"], name: "index_boost_payouts_on_site_id"
    t.index ["status"], name: "index_boost_payouts_on_status"
  end

  create_table "categories", force: :cascade do |t|
    t.boolean "allow_paths", default: true, null: false
    t.string "category_type", default: "article", null: false
    t.datetime "created_at", null: false
    t.string "display_template"
    t.string "key", null: false
    t.jsonb "metadata_schema", default: {}, null: false
    t.string "name", null: false
    t.jsonb "shown_fields", default: {}, null: false
    t.bigint "site_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "category_type"], name: "index_categories_on_site_id_and_category_type"
    t.index ["site_id", "key"], name: "index_categories_on_site_id_and_key", unique: true
    t.index ["site_id", "name"], name: "index_categories_on_site_id_and_name"
    t.index ["site_id"], name: "index_categories_on_site_id"
    t.index ["tenant_id", "key"], name: "index_categories_on_tenant_id_and_key", unique: true
    t.index ["tenant_id", "name"], name: "index_categories_on_tenant_name"
    t.index ["tenant_id"], name: "index_categories_on_tenant_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "commentable_id", null: false
    t.string "commentable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "edited_at"
    t.datetime "hidden_at"
    t.bigint "hidden_by_id"
    t.bigint "parent_id"
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["commentable_type", "commentable_id", "parent_id"], name: "index_comments_on_commentable_and_parent"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["hidden_at"], name: "index_comments_on_hidden_at"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["site_id", "user_id"], name: "index_comments_on_site_and_user"
    t.index ["site_id"], name: "index_comments_on_site_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "content_items", force: :cascade do |t|
    t.jsonb "ai_suggested_tags", default: [], null: false
    t.text "ai_summary"
    t.string "audience_tags", default: [], array: true
    t.string "author_name"
    t.integer "comments_count", default: 0, null: false
    t.datetime "comments_locked_at"
    t.bigint "comments_locked_by_id"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "editorialised_at"
    t.datetime "enriched_at"
    t.jsonb "enrichment_errors", default: [], null: false
    t.string "enrichment_status", default: "pending", null: false
    t.text "extracted_text"
    t.string "favicon_url"
    t.datetime "hidden_at"
    t.bigint "hidden_by_id"
    t.jsonb "key_takeaways", default: []
    t.string "og_image_url"
    t.datetime "published_at"
    t.decimal "quality_score", precision: 3, scale: 1
    t.jsonb "raw_payload", default: {}, null: false
    t.integer "read_time_minutes"
    t.datetime "scheduled_for"
    t.datetime "screenshot_captured_at"
    t.string "screenshot_url"
    t.bigint "site_id", null: false
    t.bigint "source_id", null: false
    t.text "summary"
    t.decimal "tagging_confidence", precision: 3, scale: 2
    t.jsonb "tagging_explanation", default: [], null: false
    t.jsonb "tags", default: [], null: false
    t.string "title"
    t.jsonb "topic_tags", default: [], null: false
    t.datetime "updated_at", null: false
    t.integer "upvotes_count", default: 0, null: false
    t.string "url_canonical", null: false
    t.text "url_raw", null: false
    t.text "why_it_matters"
    t.integer "word_count"
    t.index ["comments_locked_by_id"], name: "index_content_items_on_comments_locked_by_id"
    t.index ["enrichment_status"], name: "index_content_items_on_enrichment_status"
    t.index ["hidden_at"], name: "index_content_items_on_hidden_at"
    t.index ["hidden_by_id"], name: "index_content_items_on_hidden_by_id"
    t.index ["published_at"], name: "index_content_items_on_published_at"
    t.index ["scheduled_for"], name: "index_content_items_on_scheduled_for", where: "(scheduled_for IS NOT NULL)"
    t.index ["site_id", "content_type"], name: "index_content_items_on_site_id_and_content_type"
    t.index ["site_id", "editorialised_at"], name: "index_content_items_on_site_id_and_editorialised_at"
    t.index ["site_id", "published_at"], name: "index_content_items_on_site_id_published_at_desc", order: { published_at: :desc }
    t.index ["site_id", "url_canonical"], name: "index_content_items_on_site_id_and_url_canonical", unique: true
    t.index ["site_id"], name: "index_content_items_on_site_id"
    t.index ["source_id", "created_at"], name: "index_content_items_on_source_id_and_created_at"
    t.index ["source_id"], name: "index_content_items_on_source_id"
    t.index ["topic_tags"], name: "index_content_items_on_topic_tags_gin", using: :gin
  end

  create_table "content_views", force: :cascade do |t|
    t.bigint "content_item_id", null: false
    t.datetime "created_at", null: false
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "viewed_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["content_item_id"], name: "index_content_views_on_content_item_id"
    t.index ["site_id", "user_id", "content_item_id"], name: "index_content_views_uniqueness", unique: true
    t.index ["site_id"], name: "index_content_views_on_site_id"
    t.index ["user_id", "site_id", "viewed_at"], name: "index_content_views_on_user_site_viewed_at", order: { viewed_at: :desc }
    t.index ["user_id"], name: "index_content_views_on_user_id"
  end

  create_table "digest_subscriptions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.integer "frequency", default: 0, null: false
    t.datetime "last_sent_at"
    t.jsonb "preferences", default: {}, null: false
    t.string "referral_code", null: false
    t.bigint "site_id", null: false
    t.string "unsubscribe_token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["confirmation_token"], name: "index_digest_subscriptions_on_confirmation_token", unique: true
    t.index ["referral_code"], name: "index_digest_subscriptions_on_referral_code", unique: true
    t.index ["site_id", "frequency", "active"], name: "index_digest_subscriptions_on_site_id_and_frequency_and_active"
    t.index ["site_id"], name: "index_digest_subscriptions_on_site_id"
    t.index ["unsubscribe_token"], name: "index_digest_subscriptions_on_unsubscribe_token", unique: true
    t.index ["user_id", "site_id"], name: "index_digest_subscriptions_on_user_id_and_site_id", unique: true
    t.index ["user_id"], name: "index_digest_subscriptions_on_user_id"
  end

  create_table "digital_products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "download_count", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "price_cents", default: 0, null: false
    t.bigint "site_id", null: false
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "slug"], name: "index_digital_products_on_site_id_and_slug", unique: true
    t.index ["site_id", "status"], name: "index_digital_products_on_site_id_and_status"
    t.index ["site_id"], name: "index_digital_products_on_site_id"
  end

  create_table "discussion_posts", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "discussion_id", null: false
    t.datetime "edited_at"
    t.datetime "hidden_at"
    t.bigint "parent_id"
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["discussion_id", "created_at"], name: "index_discussion_posts_on_discussion_id_and_created_at"
    t.index ["discussion_id"], name: "index_discussion_posts_on_discussion_id"
    t.index ["parent_id"], name: "index_discussion_posts_on_parent_id"
    t.index ["site_id", "user_id"], name: "index_discussion_posts_on_site_id_and_user_id"
    t.index ["site_id"], name: "index_discussion_posts_on_site_id"
    t.index ["user_id"], name: "index_discussion_posts_on_user_id"
  end

  create_table "discussions", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "last_post_at"
    t.datetime "locked_at"
    t.bigint "locked_by_id"
    t.boolean "pinned", default: false, null: false
    t.datetime "pinned_at"
    t.integer "posts_count", default: 0, null: false
    t.bigint "site_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "visibility", default: 0, null: false
    t.index ["locked_by_id"], name: "index_discussions_on_locked_by_id"
    t.index ["site_id", "last_post_at"], name: "index_discussions_on_site_id_and_last_post_at"
    t.index ["site_id", "pinned", "last_post_at"], name: "index_discussions_on_site_id_and_pinned_and_last_post_at"
    t.index ["site_id", "visibility"], name: "index_discussions_on_site_id_and_visibility"
    t.index ["site_id"], name: "index_discussions_on_site_id"
    t.index ["user_id"], name: "index_discussions_on_user_id"
  end

  create_table "domains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname", null: false
    t.datetime "last_checked_at"
    t.text "last_error"
    t.boolean "primary", default: false, null: false
    t.bigint "site_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.datetime "verified_at"
    t.index ["hostname"], name: "index_domains_on_hostname", unique: true
    t.index ["site_id", "verified"], name: "index_domains_on_site_id_and_verified"
    t.index ["site_id"], name: "index_domains_on_site_id"
    t.index ["site_id"], name: "index_domains_on_site_id_where_primary", unique: true, where: "(\"primary\" = true)"
    t.index ["status"], name: "index_domains_on_status"
  end

  create_table "download_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "download_count", default: 0, null: false
    t.datetime "expires_at", null: false
    t.datetime "last_downloaded_at"
    t.integer "max_downloads", default: 5, null: false
    t.bigint "purchase_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_download_tokens_on_expires_at"
    t.index ["purchase_id"], name: "index_download_tokens_on_purchase_id"
    t.index ["token"], name: "index_download_tokens_on_token", unique: true
  end

  create_table "editorialisations", force: :cascade do |t|
    t.string "ai_model"
    t.bigint "content_item_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.integer "estimated_cost_cents"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.jsonb "parsed_response", default: {}, null: false
    t.text "prompt_text", null: false
    t.string "prompt_version", null: false
    t.text "raw_response"
    t.bigint "site_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "tokens_used"
    t.datetime "updated_at", null: false
    t.index ["content_item_id"], name: "index_editorialisations_on_content_item_id", unique: true
    t.index ["site_id", "created_at", "estimated_cost_cents"], name: "index_editorialisations_cost_tracking"
    t.index ["site_id", "created_at"], name: "index_editorialisations_on_site_id_and_created_at"
    t.index ["site_id", "status"], name: "index_editorialisations_on_site_id_and_status"
    t.index ["site_id"], name: "index_editorialisations_on_site_id"
  end

  create_table "email_sequences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: false, null: false
    t.string "name", null: false
    t.bigint "site_id", null: false
    t.jsonb "trigger_config", default: {}
    t.integer "trigger_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "trigger_type", "enabled"], name: "index_email_sequences_on_site_id_and_trigger_type_and_enabled"
    t.index ["site_id"], name: "index_email_sequences_on_site_id"
  end

  create_table "email_steps", force: :cascade do |t|
    t.text "body_html", null: false
    t.text "body_text"
    t.datetime "created_at", null: false
    t.integer "delay_seconds", default: 0, null: false
    t.bigint "email_sequence_id", null: false
    t.integer "position", default: 0, null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["email_sequence_id", "position"], name: "index_email_steps_on_email_sequence_id_and_position", unique: true
    t.index ["email_sequence_id"], name: "index_email_steps_on_email_sequence_id"
  end

  create_table "flags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "details"
    t.bigint "flaggable_id", null: false
    t.string "flaggable_type", null: false
    t.integer "reason", default: 0, null: false
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.bigint "site_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["flaggable_type", "flaggable_id"], name: "index_flags_on_flaggable"
    t.index ["reviewed_by_id"], name: "index_flags_on_reviewed_by_id"
    t.index ["site_id", "status"], name: "index_flags_on_site_and_status"
    t.index ["site_id", "user_id", "flaggable_type", "flaggable_id"], name: "index_flags_uniqueness", unique: true
    t.index ["site_id"], name: "index_flags_on_site_id"
    t.index ["user_id"], name: "index_flags_on_user_id"
  end

  create_table "heartbeat_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "environment", null: false
    t.datetime "executed_at", null: false
    t.string "hostname", null: false
    t.datetime "updated_at", null: false
    t.index ["environment", "executed_at"], name: "index_heartbeat_logs_on_environment_and_executed_at"
    t.index ["executed_at"], name: "index_heartbeat_logs_on_executed_at"
  end

  create_table "import_runs", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "items_count", default: 0
    t.integer "items_created", default: 0
    t.integer "items_failed", default: 0
    t.integer "items_updated", default: 0
    t.bigint "site_id", null: false
    t.bigint "source_id", null: false
    t.datetime "started_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "started_at"], name: "index_import_runs_on_site_id_and_started_at"
    t.index ["site_id"], name: "index_import_runs_on_site_id"
    t.index ["source_id", "started_at"], name: "index_import_runs_on_source_id_and_started_at"
    t.index ["source_id"], name: "index_import_runs_on_source_id"
    t.index ["status"], name: "index_import_runs_on_status"
  end

  create_table "landing_pages", force: :cascade do |t|
    t.jsonb "content", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "cta_text"
    t.string "cta_url"
    t.string "headline"
    t.string "hero_image_url"
    t.boolean "published", default: false, null: false
    t.bigint "site_id", null: false
    t.string "slug", null: false
    t.text "subheadline"
    t.bigint "tenant_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "published"], name: "index_landing_pages_on_site_id_and_published"
    t.index ["site_id", "slug"], name: "index_landing_pages_on_site_id_and_slug", unique: true
    t.index ["site_id"], name: "index_landing_pages_on_site_id"
    t.index ["tenant_id"], name: "index_landing_pages_on_tenant_id"
  end

  create_table "listings", force: :cascade do |t|
    t.jsonb "affiliate_attribution", default: {}, null: false
    t.text "affiliate_url_template"
    t.jsonb "ai_summaries", default: {}, null: false
    t.jsonb "ai_tags", default: {}, null: false
    t.text "apply_url"
    t.text "body_html"
    t.text "body_text"
    t.bigint "category_id", null: false
    t.string "company"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "domain"
    t.datetime "expires_at"
    t.bigint "featured_by_id"
    t.datetime "featured_from"
    t.datetime "featured_until"
    t.text "image_url"
    t.integer "listing_type", default: 0, null: false
    t.string "location"
    t.jsonb "metadata", default: {}, null: false
    t.boolean "paid", default: false, null: false
    t.string "payment_reference"
    t.integer "payment_status", default: 0, null: false
    t.datetime "published_at"
    t.string "salary_range"
    t.datetime "scheduled_for"
    t.bigint "site_id", null: false
    t.string "site_name"
    t.bigint "source_id"
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.bigint "tenant_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.text "url_canonical", null: false
    t.text "url_raw", null: false
    t.index ["category_id", "published_at"], name: "index_listings_on_category_published"
    t.index ["category_id"], name: "index_listings_on_category_id"
    t.index ["domain"], name: "index_listings_on_domain"
    t.index ["featured_by_id"], name: "index_listings_on_featured_by_id"
    t.index ["payment_status"], name: "index_listings_on_payment_status"
    t.index ["published_at"], name: "index_listings_on_published_at"
    t.index ["scheduled_for"], name: "index_listings_on_scheduled_for", where: "(scheduled_for IS NOT NULL)"
    t.index ["site_id", "expires_at"], name: "index_listings_on_site_expires_at"
    t.index ["site_id", "featured_from", "featured_until"], name: "index_listings_on_site_featured_dates"
    t.index ["site_id", "listing_type", "expires_at"], name: "index_listings_on_site_type_expires"
    t.index ["site_id", "listing_type"], name: "index_listings_on_site_listing_type"
    t.index ["site_id", "url_canonical"], name: "index_listings_on_site_id_and_url_canonical", unique: true
    t.index ["site_id"], name: "index_listings_on_site_id"
    t.index ["source_id"], name: "index_listings_on_source_id"
    t.index ["stripe_checkout_session_id"], name: "index_listings_on_stripe_checkout_session_id", unique: true, where: "(stripe_checkout_session_id IS NOT NULL)"
    t.index ["stripe_payment_intent_id"], name: "index_listings_on_stripe_payment_intent_id", unique: true, where: "(stripe_payment_intent_id IS NOT NULL)"
    t.index ["tenant_id", "category_id"], name: "index_listings_on_tenant_id_and_category_id"
    t.index ["tenant_id", "domain", "published_at"], name: "index_listings_on_tenant_domain_published"
    t.index ["tenant_id", "published_at", "created_at"], name: "index_listings_on_tenant_published_created"
    t.index ["tenant_id", "source_id"], name: "index_listings_on_tenant_id_and_source_id"
    t.index ["tenant_id", "title"], name: "index_listings_on_tenant_title"
    t.index ["tenant_id", "url_canonical"], name: "index_listings_on_tenant_and_url_canonical", unique: true
    t.index ["tenant_id"], name: "index_listings_on_tenant_id"
  end

  create_table "live_stream_viewers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.datetime "joined_at", null: false
    t.datetime "left_at"
    t.bigint "live_stream_id", null: false
    t.string "session_id"
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["live_stream_id", "session_id"], name: "index_live_stream_viewers_on_stream_and_session", unique: true, where: "(session_id IS NOT NULL)"
    t.index ["live_stream_id", "user_id"], name: "index_live_stream_viewers_on_stream_and_user", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["live_stream_id"], name: "index_live_stream_viewers_on_live_stream_id"
    t.index ["site_id"], name: "index_live_stream_viewers_on_site_id"
    t.index ["user_id"], name: "index_live_stream_viewers_on_user_id"
  end

  create_table "live_streams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "discussion_id"
    t.datetime "ended_at"
    t.string "mux_asset_id"
    t.string "mux_playback_id"
    t.string "mux_stream_id"
    t.integer "peak_viewers", default: 0, null: false
    t.string "replay_playback_id"
    t.datetime "scheduled_at", null: false
    t.bigint "site_id", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.string "stream_key"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "viewer_count", default: 0, null: false
    t.integer "visibility", default: 0, null: false
    t.index ["discussion_id"], name: "index_live_streams_on_discussion_id"
    t.index ["mux_stream_id"], name: "index_live_streams_on_mux_stream_id", unique: true
    t.index ["site_id", "scheduled_at"], name: "index_live_streams_on_site_id_and_scheduled_at"
    t.index ["site_id", "status"], name: "index_live_streams_on_site_id_and_status"
    t.index ["site_id"], name: "index_live_streams_on_site_id"
    t.index ["user_id"], name: "index_live_streams_on_user_id"
  end

  create_table "network_boosts", force: :cascade do |t|
    t.decimal "cpc_rate", precision: 8, scale: 2, null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.decimal "monthly_budget", precision: 10, scale: 2
    t.bigint "source_site_id", null: false
    t.decimal "spent_this_month", precision: 10, scale: 2, default: "0.0"
    t.bigint "target_site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source_site_id", "target_site_id"], name: "index_network_boosts_on_source_site_id_and_target_site_id", unique: true
    t.index ["source_site_id"], name: "index_network_boosts_on_source_site_id"
    t.index ["target_site_id", "enabled"], name: "index_network_boosts_on_target_site_id_and_enabled"
    t.index ["target_site_id"], name: "index_network_boosts_on_target_site_id"
  end

  create_table "notes", force: :cascade do |t|
    t.text "body", null: false
    t.integer "comments_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "hidden_at"
    t.bigint "hidden_by_id"
    t.jsonb "link_preview", default: {}
    t.datetime "published_at"
    t.bigint "repost_of_id"
    t.integer "reposts_count", default: 0, null: false
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.integer "upvotes_count", default: 0, null: false
    t.bigint "user_id", null: false
    t.index ["hidden_at"], name: "index_notes_on_hidden_at"
    t.index ["hidden_by_id"], name: "index_notes_on_hidden_by_id"
    t.index ["repost_of_id"], name: "index_notes_on_repost_of_id"
    t.index ["site_id", "published_at"], name: "index_notes_on_site_id_and_published_at", order: { published_at: :desc }
    t.index ["site_id"], name: "index_notes_on_site_id"
    t.index ["user_id", "created_at"], name: "index_notes_on_user_id_and_created_at", order: { created_at: :desc }
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "digital_product_id", null: false
    t.string "email", null: false
    t.datetime "purchased_at", null: false
    t.bigint "site_id", null: false
    t.integer "source", default: 0, null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["digital_product_id"], name: "index_purchases_on_digital_product_id"
    t.index ["site_id", "digital_product_id", "email"], name: "index_purchases_on_site_id_and_digital_product_id_and_email"
    t.index ["site_id", "purchased_at"], name: "index_purchases_on_site_id_and_purchased_at"
    t.index ["site_id"], name: "index_purchases_on_site_id"
    t.index ["stripe_checkout_session_id"], name: "index_purchases_on_stripe_checkout_session_id", unique: true, where: "(stripe_checkout_session_id IS NOT NULL)"
    t.index ["stripe_payment_intent_id"], name: "index_purchases_on_stripe_payment_intent_id", unique: true, where: "(stripe_payment_intent_id IS NOT NULL)"
    t.index ["user_id"], name: "index_purchases_on_user_id"
  end

  create_table "referral_reward_tiers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "digital_product_id"
    t.integer "milestone", null: false
    t.string "name", null: false
    t.jsonb "reward_data", default: {}, null: false
    t.integer "reward_type", default: 0, null: false
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["digital_product_id"], name: "index_referral_reward_tiers_on_digital_product_id"
    t.index ["site_id", "active"], name: "index_referral_reward_tiers_on_site_id_and_active"
    t.index ["site_id", "milestone"], name: "index_referral_reward_tiers_on_site_id_and_milestone", unique: true
    t.index ["site_id"], name: "index_referral_reward_tiers_on_site_id"
  end

  create_table "referrals", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "referee_ip_hash"
    t.bigint "referee_subscription_id", null: false
    t.bigint "referrer_subscription_id", null: false
    t.datetime "rewarded_at"
    t.bigint "site_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["referee_subscription_id"], name: "index_referrals_on_referee_subscription_id", unique: true
    t.index ["referrer_subscription_id", "status"], name: "index_referrals_on_referrer_subscription_id_and_status"
    t.index ["referrer_subscription_id"], name: "index_referrals_on_referrer_subscription_id"
    t.index ["site_id", "created_at"], name: "index_referrals_on_site_id_and_created_at"
    t.index ["site_id"], name: "index_referrals_on_site_id"
    t.index ["status"], name: "index_referrals_on_status"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource"
  end

  create_table "sequence_emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "email_step_id", null: false
    t.datetime "scheduled_for", null: false
    t.datetime "sent_at"
    t.bigint "sequence_enrollment_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_step_id"], name: "index_sequence_emails_on_email_step_id"
    t.index ["sequence_enrollment_id"], name: "index_sequence_emails_on_sequence_enrollment_id"
    t.index ["status", "scheduled_for"], name: "index_sequence_emails_on_status_and_scheduled_for"
  end

  create_table "sequence_enrollments", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "current_step_position", default: 0, null: false
    t.bigint "digest_subscription_id", null: false
    t.bigint "email_sequence_id", null: false
    t.datetime "enrolled_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["digest_subscription_id"], name: "index_sequence_enrollments_on_digest_subscription_id"
    t.index ["email_sequence_id", "digest_subscription_id"], name: "idx_enrollments_sequence_subscription", unique: true
    t.index ["email_sequence_id"], name: "index_sequence_enrollments_on_email_sequence_id"
    t.index ["status"], name: "index_sequence_enrollments_on_status"
  end

  create_table "site_bans", force: :cascade do |t|
    t.datetime "banned_at", null: false
    t.bigint "banned_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.text "reason"
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["banned_by_id"], name: "index_site_bans_on_banned_by_id"
    t.index ["site_id", "expires_at"], name: "index_site_bans_on_site_and_expires"
    t.index ["site_id", "user_id"], name: "index_site_bans_uniqueness", unique: true
    t.index ["site_id"], name: "index_site_bans_on_site_id"
    t.index ["user_id"], name: "index_site_bans_on_user_id"
  end

  create_table "sites", force: :cascade do |t|
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_sites_on_status"
    t.index ["tenant_id", "slug"], name: "index_sites_on_tenant_id_and_slug", unique: true
    t.index ["tenant_id", "status"], name: "index_sites_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_sites_on_tenant_id"
  end

  create_table "sources", force: :cascade do |t|
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.boolean "editorialisation_enabled", default: false, null: false
    t.boolean "enabled", default: true, null: false
    t.integer "kind", null: false
    t.datetime "last_run_at"
    t.string "last_status"
    t.string "name", null: false
    t.decimal "quality_weight", precision: 3, scale: 2, default: "1.0", null: false
    t.jsonb "schedule", default: {}, null: false
    t.bigint "site_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "name"], name: "index_sources_on_site_id_and_name", unique: true
    t.index ["site_id"], name: "index_sources_on_site_id"
    t.index ["tenant_id", "enabled"], name: "index_sources_on_tenant_id_and_enabled"
    t.index ["tenant_id", "kind"], name: "index_sources_on_tenant_id_and_kind"
    t.index ["tenant_id", "name"], name: "index_sources_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_sources_on_tenant_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "ip_address"
    t.bigint "listing_id"
    t.integer "listing_type", default: 0, null: false
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.text "reviewer_notes"
    t.bigint "site_id", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.text "url", null: false
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_submissions_on_category_id"
    t.index ["listing_id"], name: "index_submissions_on_listing_id"
    t.index ["reviewed_by_id"], name: "index_submissions_on_reviewed_by_id"
    t.index ["site_id", "status"], name: "index_submissions_on_site_id_and_status"
    t.index ["site_id"], name: "index_submissions_on_site_id"
    t.index ["status"], name: "index_submissions_on_status"
    t.index ["user_id", "status"], name: "index_submissions_on_user_id_and_status"
    t.index ["user_id"], name: "index_submissions_on_user_id"
  end

  create_table "subscriber_segments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.jsonb "rules", default: {}, null: false
    t.bigint "site_id", null: false
    t.boolean "system_segment", default: false, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "enabled"], name: "index_subscriber_segments_on_site_id_and_enabled"
    t.index ["site_id", "system_segment"], name: "index_subscriber_segments_on_site_id_and_system_segment"
    t.index ["site_id"], name: "index_subscriber_segments_on_site_id"
    t.index ["tenant_id"], name: "index_subscriber_segments_on_tenant_id"
  end

  create_table "subscriber_taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "digest_subscription_id", null: false
    t.bigint "subscriber_tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["digest_subscription_id", "subscriber_tag_id"], name: "index_subscriber_taggings_uniqueness", unique: true
    t.index ["digest_subscription_id"], name: "index_subscriber_taggings_on_digest_subscription_id"
    t.index ["subscriber_tag_id"], name: "index_subscriber_taggings_on_subscriber_tag_id"
  end

  create_table "subscriber_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "site_id", null: false
    t.string "slug", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "slug"], name: "index_subscriber_tags_on_site_id_and_slug", unique: true
    t.index ["site_id"], name: "index_subscriber_tags_on_site_id"
    t.index ["tenant_id"], name: "index_subscriber_tags_on_tenant_id"
  end

  create_table "tagging_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.text "pattern", null: false
    t.integer "priority", default: 100, null: false
    t.integer "rule_type", null: false
    t.bigint "site_id", null: false
    t.bigint "taxonomy_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "enabled"], name: "index_tagging_rules_on_site_id_and_enabled"
    t.index ["site_id", "priority"], name: "index_tagging_rules_on_site_id_and_priority"
    t.index ["site_id"], name: "index_tagging_rules_on_site_id"
    t.index ["taxonomy_id"], name: "index_tagging_rules_on_taxonomy_id"
    t.index ["tenant_id"], name: "index_tagging_rules_on_tenant_id"
  end

  create_table "taxonomies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.bigint "site_id", null: false
    t.string "slug", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "parent_id"], name: "index_taxonomies_on_site_id_and_parent_id"
    t.index ["site_id", "slug"], name: "index_taxonomies_on_site_id_and_slug", unique: true
    t.index ["site_id"], name: "index_taxonomies_on_site_id"
    t.index ["tenant_id"], name: "index_taxonomies_on_tenant_id"
  end

  create_table "tenant_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id", null: false
    t.string "role", default: "viewer", null: false
    t.bigint "tenant_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_tenant_invitations_on_invited_by_id"
    t.index ["tenant_id", "email"], name: "index_tenant_invitations_on_tenant_id_and_email", unique: true, where: "(accepted_at IS NULL)"
    t.index ["tenant_id"], name: "index_tenant_invitations_on_tenant_id"
    t.index ["token"], name: "index_tenant_invitations_on_token", unique: true
  end

  create_table "tenants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "hostname", null: false
    t.string "logo_url"
    t.jsonb "settings", default: {}, null: false
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["hostname"], name: "index_tenants_on_hostname", unique: true
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
    t.index ["status", "hostname"], name: "index_tenants_on_status_hostname"
    t.index ["status"], name: "index_tenants_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "avatar_url"
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "role_id"
    t.bigint "user_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  create_table "votes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "value", default: 1, null: false
    t.bigint "votable_id", null: false
    t.string "votable_type", null: false
    t.index ["site_id", "user_id", "votable_type", "votable_id"], name: "index_votes_uniqueness", unique: true
    t.index ["site_id"], name: "index_votes_on_site_id"
    t.index ["user_id"], name: "index_votes_on_user_id"
    t.index ["votable_type", "votable_id"], name: "index_votes_on_votable"
  end

  create_table "workflow_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "paused_at"
    t.bigint "paused_by_id"
    t.text "reason"
    t.datetime "resumed_at"
    t.bigint "resumed_by_id"
    t.bigint "source_id"
    t.bigint "tenant_id"
    t.datetime "updated_at", null: false
    t.string "workflow_subtype"
    t.string "workflow_type", null: false
    t.index ["paused_by_id"], name: "index_workflow_pauses_on_paused_by_id"
    t.index ["resumed_by_id"], name: "index_workflow_pauses_on_resumed_by_id"
    t.index ["source_id"], name: "index_workflow_pauses_on_source_id"
    t.index ["tenant_id"], name: "index_workflow_pauses_on_tenant_id"
    t.index ["workflow_type", "paused_at"], name: "index_workflow_pauses_history"
    t.index ["workflow_type", "tenant_id", "source_id"], name: "index_workflow_pauses_active_unique", unique: true, where: "(resumed_at IS NULL)"
    t.index ["workflow_type", "tenant_id"], name: "index_workflow_pauses_active_by_type_tenant", where: "(resumed_at IS NULL)"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "affiliate_clicks", "listings"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "boost_clicks", "digest_subscriptions"
  add_foreign_key "boost_clicks", "network_boosts"
  add_foreign_key "boost_impressions", "network_boosts"
  add_foreign_key "boost_impressions", "sites"
  add_foreign_key "boost_payouts", "sites"
  add_foreign_key "categories", "sites"
  add_foreign_key "categories", "tenants"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "sites"
  add_foreign_key "comments", "users"
  add_foreign_key "comments", "users", column: "hidden_by_id"
  add_foreign_key "content_items", "sites"
  add_foreign_key "content_items", "sources"
  add_foreign_key "content_items", "users", column: "comments_locked_by_id"
  add_foreign_key "content_items", "users", column: "hidden_by_id"
  add_foreign_key "content_views", "content_items"
  add_foreign_key "content_views", "sites"
  add_foreign_key "content_views", "users"
  add_foreign_key "digest_subscriptions", "sites"
  add_foreign_key "digest_subscriptions", "users"
  add_foreign_key "digital_products", "sites"
  add_foreign_key "discussion_posts", "discussion_posts", column: "parent_id"
  add_foreign_key "discussion_posts", "discussions"
  add_foreign_key "discussion_posts", "sites"
  add_foreign_key "discussion_posts", "users"
  add_foreign_key "discussions", "sites"
  add_foreign_key "discussions", "users"
  add_foreign_key "discussions", "users", column: "locked_by_id"
  add_foreign_key "domains", "sites"
  add_foreign_key "download_tokens", "purchases"
  add_foreign_key "editorialisations", "content_items"
  add_foreign_key "editorialisations", "sites"
  add_foreign_key "email_sequences", "sites"
  add_foreign_key "email_steps", "email_sequences"
  add_foreign_key "flags", "sites"
  add_foreign_key "flags", "users"
  add_foreign_key "flags", "users", column: "reviewed_by_id"
  add_foreign_key "import_runs", "sites"
  add_foreign_key "import_runs", "sources"
  add_foreign_key "landing_pages", "sites"
  add_foreign_key "landing_pages", "tenants"
  add_foreign_key "listings", "categories"
  add_foreign_key "listings", "sites"
  add_foreign_key "listings", "sources"
  add_foreign_key "listings", "tenants"
  add_foreign_key "listings", "users", column: "featured_by_id"
  add_foreign_key "live_stream_viewers", "live_streams"
  add_foreign_key "live_stream_viewers", "sites"
  add_foreign_key "live_stream_viewers", "users"
  add_foreign_key "live_streams", "discussions"
  add_foreign_key "live_streams", "sites"
  add_foreign_key "live_streams", "users"
  add_foreign_key "network_boosts", "sites", column: "source_site_id"
  add_foreign_key "network_boosts", "sites", column: "target_site_id"
  add_foreign_key "notes", "notes", column: "repost_of_id"
  add_foreign_key "notes", "sites"
  add_foreign_key "notes", "users"
  add_foreign_key "notes", "users", column: "hidden_by_id"
  add_foreign_key "purchases", "digital_products"
  add_foreign_key "purchases", "sites"
  add_foreign_key "purchases", "users"
  add_foreign_key "referral_reward_tiers", "digital_products"
  add_foreign_key "referral_reward_tiers", "sites"
  add_foreign_key "referrals", "digest_subscriptions", column: "referee_subscription_id"
  add_foreign_key "referrals", "digest_subscriptions", column: "referrer_subscription_id"
  add_foreign_key "referrals", "sites"
  add_foreign_key "sequence_emails", "email_steps"
  add_foreign_key "sequence_emails", "sequence_enrollments"
  add_foreign_key "sequence_enrollments", "digest_subscriptions"
  add_foreign_key "sequence_enrollments", "email_sequences"
  add_foreign_key "site_bans", "sites"
  add_foreign_key "site_bans", "users"
  add_foreign_key "site_bans", "users", column: "banned_by_id"
  add_foreign_key "sites", "tenants"
  add_foreign_key "sources", "sites"
  add_foreign_key "sources", "tenants"
  add_foreign_key "submissions", "categories"
  add_foreign_key "submissions", "listings"
  add_foreign_key "submissions", "sites"
  add_foreign_key "submissions", "users"
  add_foreign_key "submissions", "users", column: "reviewed_by_id"
  add_foreign_key "subscriber_segments", "sites"
  add_foreign_key "subscriber_segments", "tenants"
  add_foreign_key "subscriber_taggings", "digest_subscriptions"
  add_foreign_key "subscriber_taggings", "subscriber_tags"
  add_foreign_key "subscriber_tags", "sites"
  add_foreign_key "subscriber_tags", "tenants"
  add_foreign_key "tagging_rules", "sites"
  add_foreign_key "tagging_rules", "taxonomies"
  add_foreign_key "tagging_rules", "tenants"
  add_foreign_key "taxonomies", "sites"
  add_foreign_key "taxonomies", "taxonomies", column: "parent_id"
  add_foreign_key "taxonomies", "tenants"
  add_foreign_key "tenant_invitations", "tenants"
  add_foreign_key "tenant_invitations", "users", column: "invited_by_id"
  add_foreign_key "votes", "sites"
  add_foreign_key "votes", "users"
  add_foreign_key "workflow_pauses", "sources"
  add_foreign_key "workflow_pauses", "tenants"
  add_foreign_key "workflow_pauses", "users", column: "paused_by_id"
  add_foreign_key "workflow_pauses", "users", column: "resumed_by_id"
end
