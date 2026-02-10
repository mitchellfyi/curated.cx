# frozen_string_literal: true

class AddMissingColumnsToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :listing_type, :integer, default: 0, null: false
    add_column :entries, :ai_summaries, :jsonb, default: {}, null: false
    add_column :entries, :ai_tags, :jsonb, default: {}, null: false

    add_index :entries, [ :site_id, :listing_type ], name: "index_entries_on_site_id_and_listing_type"

    remove_index :affiliate_clicks, name: "index_affiliate_clicks_on_listing_clicked", if_exists: true
    remove_index :affiliate_clicks, name: "index_affiliate_clicks_on_listing_id", if_exists: true
    safety_assured { remove_column :affiliate_clicks, :listing_id, :bigint }
  end
end
