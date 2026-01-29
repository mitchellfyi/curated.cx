# frozen_string_literal: true

FactoryBot.define do
  factory :bookmark do
    user
    bookmarkable { association :content_item, :published }

    trait :for_listing do
      bookmarkable { association :listing }
    end
  end
end
