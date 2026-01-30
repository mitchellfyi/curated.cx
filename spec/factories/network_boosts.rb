# frozen_string_literal: true

# == Schema Information
#
# Table name: network_boosts
#
#  id               :bigint           not null, primary key
#  cpc_rate         :decimal(8, 2)    not null
#  enabled          :boolean          default(TRUE), not null
#  monthly_budget   :decimal(10, 2)
#  spent_this_month :decimal(10, 2)   default(0.0)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  source_site_id   :bigint           not null
#  target_site_id   :bigint           not null
#
FactoryBot.define do
  factory :network_boost do
    association :source_site, factory: :site
    association :target_site, factory: :site
    cpc_rate { 0.50 }
    monthly_budget { 100.00 }
    spent_this_month { 0.00 }
    enabled { true }

    trait :disabled do
      enabled { false }
    end

    trait :unlimited_budget do
      monthly_budget { nil }
    end

    trait :budget_exhausted do
      monthly_budget { 100.00 }
      spent_this_month { 100.00 }
    end

    trait :partially_spent do
      monthly_budget { 100.00 }
      spent_this_month { 50.00 }
    end

    trait :high_cpc do
      cpc_rate { 2.00 }
    end
  end
end
