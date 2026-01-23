# frozen_string_literal: true

class CreateAffiliateClicks < ActiveRecord::Migration[8.0]
  def change
    create_table :affiliate_clicks do |t|
      t.references :listing, null: false, foreign_key: true
      t.datetime :clicked_at, null: false
      t.string :ip_hash
      t.string :user_agent
      t.text :referrer

      t.timestamps
    end

    add_index :affiliate_clicks, %i[listing_id clicked_at],
              name: "index_affiliate_clicks_on_listing_clicked"
    add_index :affiliate_clicks, :clicked_at,
              name: "index_affiliate_clicks_on_clicked_at"
  end
end
