# frozen_string_literal: true

FactoryBot.define do
  factory :business_claim do
    association :entry, factory: [ :entry, :directory ]
    association :user
    status { "pending" }

    trait :verified do
      status { "verified" }
      verified_at { Time.current }
      verification_method { "email" }
    end

    trait :rejected do
      status { "rejected" }
    end

    trait :email_verification do
      verification_method { "email" }
      verification_code { SecureRandom.hex(6) }
    end

    trait :phone_verification do
      verification_method { "phone" }
      verification_code { rand(100_000..999_999).to_s }
    end

    trait :document_verification do
      verification_method { "document" }
    end
  end
end
