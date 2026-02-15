# frozen_string_literal: true

FactoryBot.define do
  factory :business_subscription do
    association :entry, factory: [ :entry, :directory ]
    association :user
    tier { "pro" }
    status { "active" }
    current_period_start { Time.current.beginning_of_month }
    current_period_end { Time.current.end_of_month }

    trait :pro do
      tier { "pro" }
    end

    trait :premium do
      tier { "premium" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :past_due do
      status { "past_due" }
    end

    trait :with_stripe do
      stripe_subscription_id { "sub_#{SecureRandom.hex(12)}" }
    end

    trait :expiring_soon do
      current_period_end { 3.days.from_now }
    end
  end
end
