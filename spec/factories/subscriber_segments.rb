# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriber_segments
#
#  id             :bigint           not null, primary key
#  description    :text
#  enabled        :boolean          default(TRUE), not null
#  name           :string           not null
#  rules          :jsonb            not null
#  system_segment :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#  tenant_id      :bigint           not null
#
# Indexes
#
#  index_subscriber_segments_on_site_id                     (site_id)
#  index_subscriber_segments_on_site_id_and_enabled         (site_id,enabled)
#  index_subscriber_segments_on_site_id_and_system_segment  (site_id,system_segment)
#  index_subscriber_segments_on_tenant_id                   (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :subscriber_segment do
    sequence(:name) { |n| "Segment #{n}" }
    site
    tenant { site.tenant }
    rules { {} }
    enabled { true }
    system_segment { false }

    trait :system do
      system_segment { true }
    end

    trait :disabled do
      enabled { false }
    end

    trait :all_subscribers do
      name { "All Subscribers" }
      system_segment { true }
      rules { {} }
    end

    trait :active_30_days do
      name { "Active (30 days)" }
      system_segment { true }
      rules { { "engagement_level" => { "min_actions" => 1, "within_days" => 30 } } }
    end

    trait :new_7_days do
      name { "New (7 days)" }
      system_segment { true }
      rules { { "subscription_age" => { "max_days" => 7 } } }
    end

    trait :power_users do
      name { "Power Users" }
      system_segment { true }
      rules { { "referral_count" => { "min" => 3 } } }
    end
  end
end
