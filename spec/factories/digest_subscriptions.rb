# frozen_string_literal: true

FactoryBot.define do
  factory :digest_subscription do
    user
    site
    frequency { :weekly }
    active { true }

    trait :daily do
      frequency { :daily }
    end

    trait :inactive do
      active { false }
    end

    trait :due do
      last_sent_at { 2.weeks.ago }
    end

    trait :recently_sent do
      last_sent_at { 1.hour.ago }
    end
  end
end
