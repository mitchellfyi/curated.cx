# frozen_string_literal: true

class CreateReferralRewardTiers < ActiveRecord::Migration[8.1]
  def change
    create_table :referral_reward_tiers do |t|
      t.references :site, null: false, foreign_key: true
      t.integer :milestone, null: false
      t.integer :reward_type, default: 0, null: false
      t.string :name, null: false
      t.text :description
      t.jsonb :reward_data, default: {}, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :referral_reward_tiers, [ :site_id, :milestone ], unique: true
    add_index :referral_reward_tiers, [ :site_id, :active ]
  end
end
