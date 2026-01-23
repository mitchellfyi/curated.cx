# frozen_string_literal: true

FactoryBot.define do
  factory :vote do
    association :content_item
    association :user
    site { content_item.site }
    value { 1 }

    trait :downvote do
      value { -1 }
    end
  end
end
