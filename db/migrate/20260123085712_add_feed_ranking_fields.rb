# frozen_string_literal: true

class AddFeedRankingFields < ActiveRecord::Migration[8.0]
  def change
    # Source quality weight for ranking
    add_column :sources, :quality_weight, :decimal, precision: 3, scale: 2, default: 1.0, null: false

    # Engagement counters for ranking (placeholders until community features)
    add_column :content_items, :upvotes_count, :integer, default: 0, null: false
    add_column :content_items, :comments_count, :integer, default: 0, null: false

    # Composite index for feed queries (site + published_at for sorting)
    add_index :content_items, %i[site_id published_at], order: { published_at: :desc },
                                                        name: "index_content_items_on_site_id_published_at_desc"

    # GIN index for topic_tags JSONB queries (faster @> containment)
    add_index :content_items, :topic_tags, using: :gin, name: "index_content_items_on_topic_tags_gin"
  end
end
