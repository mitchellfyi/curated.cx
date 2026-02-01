# frozen_string_literal: true

FactoryBot.define do
  factory :note do
    association :user
    association :site
    body { Faker::Lorem.paragraph(sentence_count: 2) }
    published_at { nil }

    trait :published do
      published_at { Time.current }
    end

    trait :draft do
      published_at { nil }
    end

    trait :hidden do
      hidden_at { Time.current }
      association :hidden_by, factory: :user
    end

    trait :with_link do
      body { "Check this out: https://example.com/article" }
    end

    trait :with_link_preview do
      link_preview do
        {
          "url" => "https://example.com/article",
          "title" => "Example Article",
          "description" => "This is an example article description",
          "image" => "https://example.com/image.jpg",
          "site_name" => "Example.com"
        }
      end
    end

    trait :repost do
      transient do
        original_note { nil }
      end

      repost_of { original_note || association(:note, :published, site: site) }
    end
  end
end
