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
# Indexes
#
#  index_purchases_on_digital_product_id                        (digital_product_id)
#  index_purchases_on_site_id                                   (site_id)
#  index_purchases_on_site_id_and_digital_product_id_and_email  (site_id,digital_product_id,email)
#  index_purchases_on_site_id_and_purchased_at                  (site_id,purchased_at)
#  index_purchases_on_stripe_checkout_session_id                (stripe_checkout_session_id) UNIQUE WHERE (stripe_checkout_session_id IS NOT NULL)
#  index_purchases_on_stripe_payment_intent_id                  (stripe_payment_intent_id) UNIQUE WHERE (stripe_payment_intent_id IS NOT NULL)
#  index_purchases_on_user_id                                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (digital_product_id => digital_products.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
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
