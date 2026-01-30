# frozen_string_literal: true

FactoryBot.define do
  factory :email_step do
    email_sequence
    sequence(:position) { |n| n }
    delay_seconds { 0 }
    subject { "Welcome to our newsletter" }
    body_html { "<p>Thank you for subscribing!</p>" }
    body_text { "Thank you for subscribing!" }

    trait :with_delay do
      delay_seconds { 86_400 } # 1 day
    end

    trait :one_day_delay do
      delay_seconds { 86_400 }
    end

    trait :three_day_delay do
      delay_seconds { 259_200 }
    end

    trait :one_week_delay do
      delay_seconds { 604_800 }
    end
  end
end
