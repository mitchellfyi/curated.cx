# frozen_string_literal: true

FactoryBot.define do
  factory :live_stream_viewer do
    association :live_stream
    association :site
    association :user
    joined_at { Time.current }

    trait :active do
      left_at { nil }
      duration_seconds { nil }
    end

    trait :completed do
      left_at { 30.minutes.from_now }
      duration_seconds { 1800 }
    end

    trait :anonymous do
      user { nil }
      session_id { SecureRandom.hex(16) }
    end
  end
end
