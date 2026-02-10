# frozen_string_literal: true

class AddMissingColumnsToEntries < ActiveRecord::Migration[8.1]
  def change
    # Only add columns if they don't exist (may already be in entries from merge migration)
    unless column_exists?(:entries, :listing_type)
      add_column :entries, :listing_type, :integer, default: 0, null: false
    end
    unless column_exists?(:entries, :ai_summaries)
      add_column :entries, :ai_summaries, :jsonb, default: {}, null: false
    end
    unless column_exists?(:entries, :ai_tags)
      add_column :entries, :ai_tags, :jsonb, default: {}, null: false
    end

    unless index_exists?(:entries, [ :site_id, :listing_type ], name: "index_entries_on_site_id_and_listing_type")
      add_index :entries, [ :site_id, :listing_type ], name: "index_entries_on_site_id_and_listing_type"
    end

    remove_index :affiliate_clicks, name: "index_affiliate_clicks_on_listing_clicked", if_exists: true
    remove_index :affiliate_clicks, name: "index_affiliate_clicks_on_listing_id", if_exists: true
    if column_exists?(:affiliate_clicks, :listing_id)
      safety_assured { remove_column :affiliate_clicks, :listing_id, :bigint }
    end
  end
end
