# frozen_string_literal: true

# == Schema Information
#
# Table name: referral_reward_tiers
#
#  id                 :bigint           not null, primary key
#  active             :boolean          default(TRUE), not null
#  description        :text
#  milestone          :integer          not null
#  name               :string           not null
#  reward_data        :jsonb            not null
#  reward_type        :integer          default("digital_download"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  digital_product_id :bigint
#  site_id            :bigint           not null
#
# Indexes
#
#  index_referral_reward_tiers_on_digital_product_id     (digital_product_id)
#  index_referral_reward_tiers_on_site_id                (site_id)
#  index_referral_reward_tiers_on_site_id_and_active     (site_id,active)
#  index_referral_reward_tiers_on_site_id_and_milestone  (site_id,milestone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (digital_product_id => digital_products.id)
#  fk_rails_...  (site_id => sites.id)
#
FactoryBot.define do
  factory :referral_reward_tier do
    site
    sequence(:milestone) { |n| n }
    name { "Referral Reward #{milestone}" }
    reward_type { :digital_download }
    active { true }

    trait :digital_download do
      reward_type { :digital_download }
      reward_data { { "download_url" => "https://example.com/download/bonus.pdf" } }
    end

    trait :featured_mention do
      reward_type { :featured_mention }
      reward_data { { "mention_details" => "Featured in next newsletter" } }
    end

    trait :custom do
      reward_type { :custom }
      reward_data { { "instructions" => "Contact us to claim your reward" } }
    end

    trait :inactive do
      active { false }
    end

    # Common milestone configurations
    trait :first_referral do
      milestone { 1 }
      name { "First Referral Reward" }
    end

    trait :three_referrals do
      milestone { 3 }
      name { "Three Referrals Reward" }
    end

    trait :five_referrals do
      milestone { 5 }
      name { "Five Referrals Reward" }
    end
  end
end
