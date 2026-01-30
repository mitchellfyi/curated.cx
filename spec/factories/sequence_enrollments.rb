# frozen_string_literal: true

FactoryBot.define do
  factory :sequence_enrollment do
    email_sequence
    digest_subscription
    status { :active }
    current_step_position { 0 }
    enrolled_at { Time.current }

    trait :completed do
      status { :completed }
      completed_at { Time.current }
    end

    trait :stopped do
      status { :stopped }
    end

    trait :in_progress do
      current_step_position { 1 }
    end
  end
end
