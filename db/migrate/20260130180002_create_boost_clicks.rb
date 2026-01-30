# frozen_string_literal: true

class CreateBoostClicks < ActiveRecord::Migration[8.0]
  def change
    create_table :boost_clicks do |t|
      t.references :network_boost, null: false, foreign_key: true
      t.string :ip_hash
      t.datetime :clicked_at, null: false
      t.datetime :converted_at
      t.references :digest_subscription, foreign_key: true
      t.decimal :earned_amount, precision: 8, scale: 2
      t.integer :status, default: 0, null: false
      t.timestamps

      t.index %i[network_boost_id clicked_at]
      t.index %i[ip_hash clicked_at]
      t.index :status
    end
  end
end
