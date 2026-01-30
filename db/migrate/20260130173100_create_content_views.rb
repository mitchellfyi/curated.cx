# frozen_string_literal: true

class CreateContentViews < ActiveRecord::Migration[8.0]
  def change
    create_table :content_views do |t|
      t.references :user, null: false, foreign_key: true
      t.references :content_item, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.datetime :viewed_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    # Unique constraint: one view record per user/content_item/site combination
    add_index :content_views, [ :site_id, :user_id, :content_item_id ],
              unique: true,
              name: "index_content_views_uniqueness"

    # Efficient lookups for user history (recent views)
    add_index :content_views, [ :user_id, :site_id, :viewed_at ],
              order: { viewed_at: :desc },
              name: "index_content_views_on_user_site_viewed_at"
  end
end
