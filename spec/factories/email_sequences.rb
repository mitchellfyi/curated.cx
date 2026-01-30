# frozen_string_literal: true

FactoryBot.define do
  factory :email_sequence do
    site
    sequence(:name) { |n| "Welcome Sequence #{n}" }
    trigger_type { :subscriber_joined }
    trigger_config { {} }
    enabled { false }

    trait :enabled do
      enabled { true }
    end

    trait :referral_milestone_trigger do
      trigger_type { :referral_milestone }
      trigger_config { { milestone: 3 } }
    end

    trait :with_steps do
      after(:create) do |sequence|
        create(:email_step, email_sequence: sequence, position: 0, delay_seconds: 0,
               subject: "Welcome!", body_html: "<p>Welcome to our newsletter!</p>")
        create(:email_step, email_sequence: sequence, position: 1, delay_seconds: 86_400,
               subject: "Getting Started", body_html: "<p>Here's how to get started...</p>")
        create(:email_step, email_sequence: sequence, position: 2, delay_seconds: 259_200,
               subject: "Did you know?", body_html: "<p>Here are some tips...</p>")
      end
    end
  end
end
