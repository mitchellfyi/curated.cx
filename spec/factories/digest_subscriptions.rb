# frozen_string_literal: true

# == Schema Information
#
# Table name: digest_subscriptions
#
#  id                    :bigint           not null, primary key
#  active                :boolean          default(TRUE), not null
#  confirmation_sent_at  :datetime
#  confirmation_token    :string
#  confirmed_at          :datetime
#  frequency             :integer          default("weekly"), not null
#  last_sent_at          :datetime
#  preferences           :jsonb            not null
#  referral_code         :string           not null
#  unsubscribe_token     :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  site_id               :bigint           not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_digest_subscriptions_on_confirmation_token               (confirmation_token) UNIQUE
#  index_digest_subscriptions_on_referral_code                     (referral_code) UNIQUE
#  index_digest_subscriptions_on_site_id                           (site_id)
#  index_digest_subscriptions_on_site_id_and_frequency_and_active  (site_id,frequency,active)
#  index_digest_subscriptions_on_unsubscribe_token                 (unsubscribe_token) UNIQUE
#  index_digest_subscriptions_on_user_id                           (user_id)
#  index_digest_subscriptions_on_user_id_and_site_id               (user_id,site_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :digest_subscription do
    user
    site
    frequency { :weekly }
    active { true }
    confirmed_at { Time.current } # Default to confirmed for backward compatibility

    trait :daily do
      frequency { :daily }
    end

    trait :inactive do
      active { false }
    end

    trait :due do
      last_sent_at { 2.weeks.ago }
    end

    trait :recently_sent do
      last_sent_at { 1.hour.ago }
    end

    trait :confirmed do
      confirmed_at { Time.current }
      confirmation_token { nil }
    end

    trait :pending_confirmation do
      confirmed_at { nil }
      confirmation_token { SecureRandom.urlsafe_base64(32) }
    end
  end
end
