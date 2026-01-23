# frozen_string_literal: true

# == Schema Information
#
# Table name: tagging_rules
#
#  id          :bigint           not null, primary key
#  enabled     :boolean          default(TRUE), not null
#  pattern     :text             not null
#  priority    :integer          default(100), not null
#  rule_type   :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  site_id     :bigint           not null
#  taxonomy_id :bigint           not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_tagging_rules_on_site_id               (site_id)
#  index_tagging_rules_on_site_id_and_enabled   (site_id,enabled)
#  index_tagging_rules_on_site_id_and_priority  (site_id,priority)
#  index_tagging_rules_on_taxonomy_id           (taxonomy_id)
#  index_tagging_rules_on_tenant_id             (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (taxonomy_id => taxonomies.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :tagging_rule do
    association :taxonomy
    site { taxonomy.site }
    # tenant is set from site in callback
    rule_type { :url_pattern }
    pattern { "example\\.com/news/.*" }
    priority { 100 }
    enabled { true }

    trait :url_pattern do
      rule_type { :url_pattern }
      pattern { "example\\.com/news/.*" }
    end

    trait :source_based do
      rule_type { :source }
      pattern { "1" }
    end

    trait :keyword do
      rule_type { :keyword }
      pattern { "technology, innovation, startup" }
    end

    trait :domain do
      rule_type { :domain }
      pattern { "*.techcrunch.com" }
    end

    trait :disabled do
      enabled { false }
    end

    trait :high_priority do
      priority { 10 }
    end

    trait :low_priority do
      priority { 1000 }
    end
  end
end
