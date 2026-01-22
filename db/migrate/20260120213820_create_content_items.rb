# frozen_string_literal: true

class CreateContentItems < ActiveRecord::Migration[8.0]
  def change
    create_table :content_items do |t|
      t.references :site, null: false, foreign_key: true
      t.references :source, null: false, foreign_key: true
      t.string :url_canonical, null: false
      t.text :url_raw, null: false
      t.string :title
      t.text :description
      t.text :extracted_text
      t.jsonb :raw_payload, default: {}, null: false
      t.jsonb :tags, default: [], null: false
      t.text :summary
      t.datetime :published_at

      t.timestamps
    end

    # Deduplication: unique canonical URL per site
    add_index :content_items, [ :site_id, :url_canonical ], unique: true
    add_index :content_items, [ :source_id, :created_at ]
    add_index :content_items, :published_at
  end
end
