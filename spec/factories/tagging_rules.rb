# frozen_string_literal: true

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
