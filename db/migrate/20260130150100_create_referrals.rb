# frozen_string_literal: true

class CreateReferrals < ActiveRecord::Migration[8.1]
  def change
    create_table :referrals do |t|
      t.references :referrer_subscription, null: false, foreign_key: { to_table: :digest_subscriptions }, index: true
      t.references :referee_subscription, null: false, foreign_key: { to_table: :digest_subscriptions }, index: { unique: true }
      t.references :site, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.string :referee_ip_hash
      t.datetime :confirmed_at
      t.datetime :rewarded_at

      t.timestamps
    end

    add_index :referrals, :status
    add_index :referrals, [ :referrer_subscription_id, :status ]
    add_index :referrals, [ :site_id, :created_at ]
  end
end
