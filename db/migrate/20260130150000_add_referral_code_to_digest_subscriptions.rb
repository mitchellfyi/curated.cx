# frozen_string_literal: true

class AddReferralCodeToDigestSubscriptions < ActiveRecord::Migration[8.1]
  def up
    # Add referral_code column (nullable initially for backfill)
    add_column :digest_subscriptions, :referral_code, :string

    # Add unique index
    add_index :digest_subscriptions, :referral_code, unique: true

    # Backfill existing records
    DigestSubscription.unscoped.where(referral_code: nil).find_each do |subscription|
      subscription.update_column(:referral_code, SecureRandom.urlsafe_base64(8))
    end

    # Add NOT NULL constraint after backfill
    change_column_null :digest_subscriptions, :referral_code, false
  end

  def down
    remove_column :digest_subscriptions, :referral_code
  end
end
