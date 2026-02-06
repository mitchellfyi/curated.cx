# frozen_string_literal: true

FactoryBot.define do
  factory :tenant_invitation do
    association :tenant
    association :invited_by, factory: :user
    email { Faker::Internet.email }
    role { "editor" }
    expires_at { 7.days.from_now }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :accepted do
      accepted_at { 1.day.ago }
    end
  end
end
