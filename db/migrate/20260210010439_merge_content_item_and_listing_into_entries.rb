# frozen_string_literal: true

class MergeContentItemAndListingIntoEntries < ActiveRecord::Migration[8.1]
  def up
    create_entries_table
    point_affiliate_clicks_to_entries
    point_editorialisations_to_entries
    point_content_views_to_entries
    point_submissions_to_entries
    safety_assured do
      drop_table :content_items if table_exists?(:content_items)
      drop_table :listings if table_exists?(:listings)
    end
  end

  def down
    create_table :content_items do |t|
      t.jsonb :ai_suggested_tags, default: [], null: false
      t.text :ai_summary
      t.string :audience_tags, default: [], array: true
      t.string :author_name
      t.integer :comments_count, default: 0, null: false
      t.datetime :comments_locked_at
      t.bigint :comments_locked_by_id
      t.string :content_type
      t.datetime :created_at, null: false
      t.text :description
      t.datetime :editorialised_at
      t.datetime :enriched_at
      t.jsonb :enrichment_errors, default: [], null: false
      t.string :enrichment_status, default: "pending", null: false
      t.text :extracted_text
      t.string :favicon_url
      t.datetime :hidden_at
      t.bigint :hidden_by_id
      t.jsonb :key_takeaways, default: []
      t.string :og_image_url
      t.datetime :published_at
      t.decimal :quality_score, precision: 3, scale: 1
      t.jsonb :raw_payload, default: {}, null: false
      t.integer :read_time_minutes
      t.datetime :scheduled_for
      t.datetime :screenshot_captured_at
      t.string :screenshot_url
      t.bigint :site_id, null: false
      t.bigint :source_id, null: false
      t.text :summary
      t.decimal :tagging_confidence, precision: 3, scale: 2
      t.jsonb :tagging_explanation, default: [], null: false
      t.jsonb :tags, default: [], null: false
      t.string :title
      t.jsonb :topic_tags, default: [], null: false
      t.datetime :updated_at, null: false
      t.integer :upvotes_count, default: 0, null: false
      t.string :url_canonical, null: false
      t.text :url_raw, null: false
      t.text :why_it_matters
      t.integer :word_count
    end
    create_table :listings do |t|
      t.jsonb :affiliate_attribution, default: {}, null: false
      t.text :affiliate_url_template
      t.jsonb :ai_summaries, default: {}, null: false
      t.jsonb :ai_tags, default: {}, null: false
      t.text :apply_url
      t.text :body_html
      t.text :body_text
      t.bigint :category_id, null: false
      t.string :company
      t.datetime :created_at, null: false
      t.text :description
      t.string :domain
      t.datetime :expires_at
      t.bigint :featured_by_id
      t.datetime :featured_from
      t.datetime :featured_until
      t.text :image_url
      t.integer :listing_type, default: 0, null: false
      t.string :location
      t.jsonb :metadata, default: {}, null: false
      t.boolean :paid, default: false, null: false
      t.string :payment_reference
      t.integer :payment_status, default: 0, null: false
      t.datetime :published_at
      t.string :salary_range
      t.datetime :scheduled_for
      t.bigint :site_id, null: false
      t.string :site_name
      t.bigint :source_id
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.bigint :tenant_id, null: false
      t.string :title
      t.datetime :updated_at, null: false
      t.text :url_canonical, null: false
      t.text :url_raw, null: false
    end
    add_column :affiliate_clicks, :listing_id, :bigint
    add_foreign_key :affiliate_clicks, :listings
    remove_foreign_key :affiliate_clicks, :entries
    remove_column :affiliate_clicks, :entry_id
    add_column :editorialisations, :content_item_id, :bigint
    add_foreign_key :editorialisations, :content_items
    remove_foreign_key :editorialisations, :entries
    remove_column :editorialisations, :entry_id
    add_column :content_views, :content_item_id, :bigint
    add_foreign_key :content_views, :content_items
    remove_foreign_key :content_views, :entries
    remove_column :content_views, :entry_id
    add_column :submissions, :listing_id, :bigint
    add_foreign_key :submissions, :listings
    remove_foreign_key :submissions, :entries
    remove_column :submissions, :entry_id
    drop_table :entries
  end

  private

  def create_entries_table
    return if table_exists?(:entries)
    create_table :entries do |t|
      # Discriminator
      t.string :entry_kind, null: false, default: "feed"
      # ContentItem columns
      t.jsonb :ai_suggested_tags, default: [], null: false
      t.text :ai_summary
      t.string :audience_tags, default: [], array: true
      t.string :author_name
      t.integer :comments_count, default: 0, null: false
      t.datetime :comments_locked_at
      t.bigint :comments_locked_by_id
      t.string :content_type
      t.datetime :created_at, null: false
      t.text :description
      t.datetime :editorialised_at
      t.datetime :enriched_at
      t.jsonb :enrichment_errors, default: [], null: false
      t.string :enrichment_status, default: "pending", null: false
      t.text :extracted_text
      t.string :favicon_url
      t.datetime :hidden_at
      t.bigint :hidden_by_id
      t.jsonb :key_takeaways, default: []
      t.string :og_image_url
      t.datetime :published_at
      t.decimal :quality_score, precision: 3, scale: 1
      t.jsonb :raw_payload, default: {}, null: false
      t.integer :read_time_minutes
      t.datetime :scheduled_for
      t.datetime :screenshot_captured_at
      t.string :screenshot_url
      t.bigint :site_id, null: false
      t.bigint :source_id
      t.text :summary
      t.decimal :tagging_confidence, precision: 3, scale: 2
      t.jsonb :tagging_explanation, default: [], null: false
      t.jsonb :tags, default: [], null: false
      t.string :title
      t.jsonb :topic_tags, default: [], null: false
      t.datetime :updated_at, null: false
      t.integer :upvotes_count, default: 0, null: false
      t.string :url_canonical, null: false
      t.text :url_raw, null: false
      t.text :why_it_matters
      t.integer :word_count
      # Listing-only columns
      t.bigint :tenant_id
      t.bigint :category_id
      t.string :company
      t.string :location
      t.string :salary_range
      t.text :apply_url
      t.text :body_html
      t.text :body_text
      t.text :image_url
      t.string :domain
      t.string :site_name
      t.jsonb :metadata, default: {}, null: false
      t.text :affiliate_url_template
      t.jsonb :affiliate_attribution, default: {}, null: false
      t.datetime :featured_from
      t.datetime :featured_until
      t.bigint :featured_by_id
      t.boolean :paid, default: false, null: false
      t.integer :payment_status, default: 0, null: false
      t.string :payment_reference
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.datetime :expires_at
    end
    add_foreign_key :entries, :sites
    add_foreign_key :entries, :sources
    add_foreign_key :entries, :tenants
    add_foreign_key :entries, :categories
    add_foreign_key :entries, :users, column: :comments_locked_by_id
    add_foreign_key :entries, :users, column: :hidden_by_id
    add_foreign_key :entries, :users, column: :featured_by_id
    add_index :entries, :comments_locked_by_id
    add_index :entries, :enrichment_status
    add_index :entries, :hidden_at
    add_index :entries, :hidden_by_id
    add_index :entries, :published_at
    add_index :entries, :scheduled_for, where: "scheduled_for IS NOT NULL"
    add_index :entries, [ :site_id, :content_type ], name: "index_entries_on_site_id_and_content_type"
    add_index :entries, [ :site_id, :editorialised_at ], name: "index_entries_on_site_id_and_editorialised_at"
    add_index :entries, [ :site_id, :published_at ], name: "index_entries_on_site_id_published_at_desc", order: { published_at: :desc }
    add_index :entries, [ :site_id, :entry_kind, :url_canonical ], name: "index_entries_on_site_kind_canonical", unique: true
    add_index :entries, :site_id
    add_index :entries, [ :source_id, :created_at ], name: "index_entries_on_source_id_and_created_at"
    add_index :entries, :source_id
    add_index :entries, :topic_tags, using: :gin
    add_index :entries, :entry_kind
    add_index :entries, :category_id
    add_index :entries, :tenant_id
    add_index :entries, [ :category_id, :published_at ], name: "index_entries_on_category_published"
    add_index :entries, :domain
    add_index :entries, :featured_by_id
    add_index :entries, :payment_status
    add_index :entries, [ :site_id, :expires_at ], name: "index_entries_on_site_expires_at"
    add_index :entries, [ :site_id, :featured_from, :featured_until ], name: "index_entries_on_site_featured_dates"
    add_index :entries, [ :tenant_id, :category_id ], name: "index_entries_on_tenant_id_and_category_id"
    add_index :entries, [ :tenant_id, :published_at, :created_at ], name: "index_entries_on_tenant_published_created"
    add_index :entries, [ :tenant_id, :source_id ], name: "index_entries_on_tenant_id_and_source_id"
    add_index :entries, [ :tenant_id, :title ], name: "index_entries_on_tenant_title"
    add_index :entries, [ :tenant_id, :url_canonical ], name: "index_entries_on_tenant_and_url_canonical"
    add_index :entries, :stripe_checkout_session_id, unique: true, where: "stripe_checkout_session_id IS NOT NULL"
    add_index :entries, :stripe_payment_intent_id, unique: true, where: "stripe_payment_intent_id IS NOT NULL"
  end

  def point_affiliate_clicks_to_entries
    return if column_exists?(:affiliate_clicks, :entry_id)
    remove_foreign_key :affiliate_clicks, :listings
    add_reference :affiliate_clicks, :entry, null: false, foreign_key: true
    remove_index :affiliate_clicks, name: "index_affiliate_clicks_on_listing_clicked" if index_exists?(:affiliate_clicks, [ :listing_id, :clicked_at ], name: "index_affiliate_clicks_on_listing_clicked")
    safety_assured { remove_column :affiliate_clicks, :listing_id }
    add_index :affiliate_clicks, [ :entry_id, :clicked_at ], name: "index_affiliate_clicks_on_entry_clicked"
  end

  def point_editorialisations_to_entries
    unless column_exists?(:editorialisations, :entry_id)
      remove_foreign_key :editorialisations, :content_items
      remove_index :editorialisations, name: "index_editorialisations_on_content_item_id" if index_exists?(:editorialisations, :content_item_id)
      add_reference :editorialisations, :entry, null: false, foreign_key: true, index: false
      safety_assured { remove_column :editorialisations, :content_item_id }
    end
    add_index :editorialisations, :entry_id, unique: true, name: "index_editorialisations_on_entry_id" unless index_exists?(:editorialisations, :entry_id, name: "index_editorialisations_on_entry_id")
  end

  def point_content_views_to_entries
    return if column_exists?(:content_views, :entry_id)
    remove_foreign_key :content_views, :content_items
    remove_index :content_views, name: "index_content_views_uniqueness" if index_exists?(:content_views, [ :site_id, :user_id, :content_item_id ], name: "index_content_views_uniqueness")
    remove_index :content_views, name: "index_content_views_on_content_item_id" if index_exists?(:content_views, :content_item_id)
    add_reference :content_views, :entry, null: false, foreign_key: true
    safety_assured { remove_column :content_views, :content_item_id }
    add_index :content_views, [ :site_id, :user_id, :entry_id ], name: "index_content_views_uniqueness", unique: true
  end

  def point_submissions_to_entries
    return if column_exists?(:submissions, :entry_id)
    remove_foreign_key :submissions, :listings
    remove_index :submissions, name: "index_submissions_on_listing_id" if index_exists?(:submissions, :listing_id)
    add_reference :submissions, :entry, null: true, foreign_key: true
    safety_assured { remove_column :submissions, :listing_id }
  end
end
