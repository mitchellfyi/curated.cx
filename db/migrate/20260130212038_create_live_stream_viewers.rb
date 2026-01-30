# frozen_string_literal: true

class CreateLiveStreamViewers < ActiveRecord::Migration[8.1]
  def change
    create_table :live_stream_viewers do |t|
      t.references :live_stream, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.string :session_id
      t.datetime :joined_at, null: false
      t.datetime :left_at
      t.integer :duration_seconds

      t.timestamps
    end

    # Unique index for logged-in users (one session per user per stream)
    add_index :live_stream_viewers, %i[live_stream_id user_id],
              unique: true,
              where: "user_id IS NOT NULL",
              name: "index_live_stream_viewers_on_stream_and_user"

    # Unique index for anonymous viewers (by session_id)
    add_index :live_stream_viewers, %i[live_stream_id session_id],
              unique: true,
              where: "session_id IS NOT NULL",
              name: "index_live_stream_viewers_on_stream_and_session"

    # Note: site_id index is already created by t.references :site
  end
end
