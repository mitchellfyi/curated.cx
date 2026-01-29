# frozen_string_literal: true

FactoryBot.define do
  factory :submission do
    user
    site
    category { association :category, site: site, tenant: site.tenant }
    url { Faker::Internet.url }
    title { Faker::Lorem.sentence(word_count: 4) }
    description { Faker::Lorem.paragraph }
    listing_type { :tool }
    status { :pending }
    ip_address { Faker::Internet.ip_v4_address }

    trait :pending do
      status { :pending }
    end

    trait :approved do
      status { :approved }
      reviewed_at { Time.current }
      reviewed_by_id { association(:user).id }
    end

    trait :rejected do
      status { :rejected }
      reviewed_at { Time.current }
      reviewer_notes { "Does not meet our guidelines." }
      reviewed_by_id { association(:user).id }
    end

    trait :job do
      listing_type { :job }
    end

    trait :service do
      listing_type { :service }
    end
  end
end
