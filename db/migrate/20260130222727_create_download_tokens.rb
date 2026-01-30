# frozen_string_literal: true

class CreateDownloadTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :download_tokens do |t|
      t.references :purchase, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.integer :download_count, null: false, default: 0
      t.integer :max_downloads, null: false, default: 5
      t.datetime :last_downloaded_at

      t.timestamps
    end

    add_index :download_tokens, :token, unique: true
    add_index :download_tokens, :expires_at
  end
end
