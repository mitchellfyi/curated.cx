# frozen_string_literal: true

class CreateVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :votes do |t|
      t.references :site, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :content_item, null: false, foreign_key: true
      t.integer :value, default: 1, null: false

      t.timestamps
    end

    # Ensure one vote per user per content item per site
    add_index :votes, %i[site_id user_id content_item_id], unique: true, name: "index_votes_uniqueness"
  end
end
