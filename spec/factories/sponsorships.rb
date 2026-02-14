# frozen_string_literal: true

FactoryBot.define do
  factory :sponsorship do
    association :user
    site { Current.site || association(:site) }
    placement_type { "featured" }
    starts_at { Time.current }
    ends_at { 30.days.from_now }
    budget_cents { 10_000 }
    status { "pending" }

    trait :active do
      status { "active" }
    end

    trait :paused do
      status { "paused" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :rejected do
      status { "rejected" }
    end

    trait :with_entry do
      association :entry, factory: [ :entry, :directory ]
    end

    trait :featured do
      placement_type { "featured" }
    end

    trait :boosted do
      placement_type { "boosted" }
    end

    trait :category_sponsor do
      placement_type { "category_sponsor" }
      category_slug { "design-tools" }
    end

    trait :with_performance do
      impressions { 1000 }
      clicks { 50 }
      spent_cents { 5000 }
    end
  end
end
