# frozen_string_literal: true

FactoryBot.define do
  factory :taxonomy do
    association :site
    # tenant is set from site in callback
    sequence(:name) { |n| "Taxonomy #{n}" }
    sequence(:slug) { |n| "taxonomy-#{n}" }
    description { Faker::Lorem.sentence }
    position { 0 }

    trait :with_parent do
      association :parent, factory: :taxonomy
      site { parent.site }
    end

    trait :with_children do
      after(:create) do |taxonomy|
        create_list(:taxonomy, 2, parent: taxonomy, site: taxonomy.site)
      end
    end

    trait :with_tagging_rules do
      after(:create) do |taxonomy|
        create_list(:tagging_rule, 2, taxonomy: taxonomy, site: taxonomy.site)
      end
    end
  end
end
