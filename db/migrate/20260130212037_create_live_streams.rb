# frozen_string_literal: true

class CreateLiveStreams < ActiveRecord::Migration[8.1]
  def change
    create_table :live_streams do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :scheduled_at, null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :status, null: false, default: 0
      t.integer :visibility, null: false, default: 0
      t.string :mux_stream_id
      t.string :mux_playback_id
      t.string :stream_key
      t.string :mux_asset_id
      t.string :replay_playback_id
      t.integer :viewer_count, null: false, default: 0
      t.integer :peak_viewers, null: false, default: 0
      t.references :site, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :discussion, foreign_key: true

      t.timestamps
    end

    add_index :live_streams, %i[site_id status]
    add_index :live_streams, %i[site_id scheduled_at]
    add_index :live_streams, :mux_stream_id, unique: true
  end
end
