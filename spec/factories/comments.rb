# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    association :content_item
    association :user
    site { content_item.site }
    body { Faker::Lorem.paragraph }
    parent { nil }

    trait :reply do
      transient do
        parent_comment { nil }
      end

      parent { parent_comment || association(:comment, content_item: content_item, site: site) }
    end

    trait :edited do
      edited_at { 1.hour.ago }
    end

    trait :long do
      body { Faker::Lorem.paragraphs(number: 10).join("\n\n") }
    end
  end
end
