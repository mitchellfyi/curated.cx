# frozen_string_literal: true

# == Schema Information
#
# Table name: purchases
#
#  id                         :bigint           not null, primary key
#  amount_cents               :integer          default(0), not null
#  email                      :string           not null
#  purchased_at               :datetime         not null
#  source                     :integer          default("checkout"), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  digital_product_id         :bigint           not null
#  site_id                    :bigint           not null
#  stripe_checkout_session_id :string
#  stripe_payment_intent_id   :string
#  user_id                    :bigint
#
FactoryBot.define do
  factory :purchase do
    association :digital_product
    site { digital_product&.site || association(:site) }
    sequence(:email) { |n| "buyer#{n}@example.com" }
    amount_cents { digital_product&.price_cents || 999 }
    source { :checkout }
    purchased_at { Time.current }

    trait :from_checkout do
      source { :checkout }
      sequence(:stripe_checkout_session_id) { |n| "cs_test_#{SecureRandom.hex(16)}" }
      sequence(:stripe_payment_intent_id) { |n| "pi_test_#{SecureRandom.hex(16)}" }
    end

    trait :from_referral do
      source { :referral }
      amount_cents { 0 }
      stripe_checkout_session_id { nil }
      stripe_payment_intent_id { nil }
    end

    trait :admin_grant do
      source { :admin_grant }
      amount_cents { 0 }
      stripe_checkout_session_id { nil }
      stripe_payment_intent_id { nil }
    end

    trait :free_purchase do
      amount_cents { 0 }
    end

    trait :with_user do
      association :user
    end

    trait :with_download_token do
      after(:create) do |purchase|
        create(:download_token, purchase: purchase)
      end
    end
  end
end
