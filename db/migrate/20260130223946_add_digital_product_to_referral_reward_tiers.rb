# frozen_string_literal: true

class AddDigitalProductToReferralRewardTiers < ActiveRecord::Migration[8.1]
  def change
    add_reference :referral_reward_tiers, :digital_product, null: true, foreign_key: true
  end
end
