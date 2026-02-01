# frozen_string_literal: true

class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.references :site, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :hidden_by, foreign_key: { to_table: :users }
      t.references :repost_of, foreign_key: { to_table: :notes }
      t.text :body, null: false
      t.jsonb :link_preview, default: {}
      t.datetime :published_at
      t.datetime :hidden_at
      t.integer :upvotes_count, default: 0, null: false
      t.integer :comments_count, default: 0, null: false
      t.integer :reposts_count, default: 0, null: false

      t.timestamps
    end

    # Feed query: site's published notes, ordered by newest
    add_index :notes, [ :site_id, :published_at ], order: { published_at: :desc }

    # User's notes, ordered by newest
    add_index :notes, [ :user_id, :created_at ], order: { created_at: :desc }

    # Note: repost_of_id index is automatically created by t.references above

    # Moderation queries
    add_index :notes, :hidden_at
  end
end
