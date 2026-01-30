# frozen_string_literal: true

FactoryBot.define do
  factory :sequence_email do
    sequence_enrollment
    email_step
    status { :pending }
    scheduled_for { Time.current }

    trait :sent do
      status { :sent }
      sent_at { Time.current }
    end

    trait :failed do
      status { :failed }
    end

    trait :due do
      scheduled_for { 1.minute.ago }
    end

    trait :future do
      scheduled_for { 1.day.from_now }
    end
  end
end
