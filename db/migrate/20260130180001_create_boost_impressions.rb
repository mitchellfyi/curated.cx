# frozen_string_literal: true

class CreateBoostImpressions < ActiveRecord::Migration[8.0]
  def change
    create_table :boost_impressions do |t|
      t.references :network_boost, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.string :ip_hash
      t.datetime :shown_at, null: false
      t.timestamps

      t.index %i[network_boost_id shown_at]
      t.index %i[site_id shown_at]
    end
  end
end
