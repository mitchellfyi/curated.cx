# frozen_string_literal: true

FactoryBot.define do
  factory :site_ban do
    association :site
    association :user
    association :banned_by, factory: :user
    reason { Faker::Lorem.sentence }
    banned_at { Time.current }
    expires_at { nil }

    trait :temporary do
      expires_at { 1.week.from_now }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :permanent do
      expires_at { nil }
    end
  end
end
