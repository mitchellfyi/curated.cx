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
FactoryBot.define do
  factory :referral do
    association :referrer_subscription, factory: :digest_subscription
    association :referee_subscription, factory: :digest_subscription
    site { referrer_subscription.site }
    status { :pending }

    trait :confirmed do
      status { :confirmed }
      confirmed_at { Time.current }
    end

    trait :rewarded do
      status { :rewarded }
      confirmed_at { 1.day.ago }
      rewarded_at { Time.current }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :with_ip_hash do
      referee_ip_hash { Digest::SHA256.hexdigest("192.168.1.1") }
    end
  end
end
