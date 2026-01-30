# frozen_string_literal: true

# == Schema Information
#
# Table name: referrals
#
#  id                       :bigint           not null, primary key
#  confirmed_at             :datetime
#  referee_ip_hash          :string
#  rewarded_at              :datetime
#  status                   :integer          default("pending"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  referee_subscription_id  :bigint           not null
#  referrer_subscription_id :bigint           not null
#  site_id                  :bigint           not null
#
# Indexes
#
#  index_referrals_on_referee_subscription_id              (referee_subscription_id) UNIQUE
#  index_referrals_on_referrer_subscription_id             (referrer_subscription_id)
#  index_referrals_on_referrer_subscription_id_and_status  (referrer_subscription_id,status)
#  index_referrals_on_site_id                              (site_id)
#  index_referrals_on_site_id_and_created_at               (site_id,created_at)
#  index_referrals_on_status                               (status)
#
# Foreign Keys
#
#  fk_rails_...  (referee_subscription_id => digest_subscriptions.id)
#  fk_rails_...  (referrer_subscription_id => digest_subscriptions.id)
#  fk_rails_...  (site_id => sites.id)
#
class Referral < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :referrer_subscription, class_name: "DigestSubscription", inverse_of: :referrals_as_referrer
  belongs_to :referee_subscription, class_name: "DigestSubscription", inverse_of: :referral_as_referee

  # Enums
  enum :status, { pending: 0, confirmed: 1, rewarded: 2, cancelled: 3 }, default: :pending

  # Validations
  validates :referee_subscription_id, uniqueness: { message: "has already been referred" }
  validates :status, presence: true

  # Scopes
  scope :for_referrer, ->(subscription) { where(referrer_subscription: subscription) }
  scope :recent, -> { order(created_at: :desc) }

  # Confirm the referral (called after 24h verification)
  def confirm!
    return false unless pending?

    update!(status: :confirmed, confirmed_at: Time.current)
    true
  end

  # Mark as rewarded
  def mark_rewarded!
    return false unless confirmed?

    update!(status: :rewarded, rewarded_at: Time.current)
    true
  end

  # Cancel the referral (e.g., referee unsubscribed before confirmation)
  def cancel!
    return false if rewarded?

    update!(status: :cancelled)
    true
  end

  # Helper to get referrer user
  def referrer_user
    referrer_subscription.user
  end

  # Helper to get referee user
  def referee_user
    referee_subscription.user
  end
end
