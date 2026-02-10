# frozen_string_literal: true

FactoryBot.define do
  factory :entry do
    association :source
    site { source&.site }
    entry_kind { "feed" }

    sequence(:url_raw) { |n| "https://example.com/article-#{n}?utm_source=test" }
    url_canonical { url_raw }
    title { Faker::Lorem.sentence }
    description { Faker::Lorem.paragraph }
    published_at { 1.hour.ago }

    # ---------------------------------------------------------------
    # Feed traits (entry_kind: "feed")
    # ---------------------------------------------------------------

    trait :feed do
      entry_kind { "feed" }
      extracted_text { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
      raw_payload do
        {
          "original_title" => title,
          "original_url" => url_raw,
          "fetched_at" => Time.current.iso8601
        }
      end
      tags { [ Faker::Lorem.word, Faker::Lorem.word ] }
      summary { Faker::Lorem.sentence }
    end

    trait :with_ai_content do
      after(:create) do |entry|
        entry.update_columns(
          ai_summary: Faker::Lorem.paragraph,
          why_it_matters: Faker::Lorem.paragraph,
          editorialised_at: Time.current
        )
      end
    end

    trait :with_enhanced_editorial do
      after(:create) do |entry|
        entry.update_columns(
          ai_summary: Faker::Lorem.paragraph,
          why_it_matters: Faker::Lorem.paragraph,
          key_takeaways: [ "First key insight", "Second key insight", "Third key insight" ],
          audience_tags: %w[developers tech\ leads],
          quality_score: 7.5,
          editorialised_at: Time.current
        )
      end
    end

    trait :article do
      after(:create) { |e| e.update_columns(content_type: "article") }
    end

    trait :video do
      after(:create) { |e| e.update_columns(content_type: "video") }
    end

    trait :tagged_tech do
      after(:create) { |e| e.update_columns(topic_tags: %w[tech technology]) }
    end

    trait :with_screenshot do
      after(:create) do |entry|
        entry.update_columns(
          screenshot_url: "https://screenshots.example.com/#{entry.id}.png",
          screenshot_captured_at: Time.current
        )
      end
    end

    trait :with_stale_screenshot do
      after(:create) do |entry|
        entry.update_columns(
          screenshot_url: "https://screenshots.example.com/#{entry.id}.png",
          screenshot_captured_at: 8.days.ago
        )
      end
    end

    trait :enrichment_complete do
      after(:create) { |e| e.update_columns(enrichment_status: "complete", enriched_at: Time.current) }
    end

    trait :enrichment_failed do
      after(:create) do |e|
        e.update_columns(
          enrichment_status: "failed",
          enrichment_errors: [ { error: "Test error", at: Time.current.iso8601 } ].to_json
        )
      end
    end

    trait :enrichment_stale do
      after(:create) { |e| e.update_columns(enrichment_status: "complete", enriched_at: 31.days.ago) }
    end

    # ---------------------------------------------------------------
    # Directory traits (entry_kind: "directory")
    # ---------------------------------------------------------------

    trait :directory do
      entry_kind { "directory" }
      association :category
      tenant { category&.tenant }
      site { category&.site }
      source { nil }
      raw_payload { {} }
      tags { [] }
      sequence(:url_raw) { |n| "https://example#{n}.com" }
      image_url { Faker::Internet.url(host: "images.example.com", path: "/image.jpg") }
      site_name { Faker::Company.name }
      body_html { Faker::Lorem.paragraphs(number: 3).map { |p| "<p>#{p}</p>" }.join }
      body_text { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    end

    trait :tool do
      directory
      listing_type { 0 }
    end

    trait :job do
      directory
      listing_type { 1 }
      company { Faker::Company.name }
      location { "#{Faker::Address.city}, #{Faker::Address.country}" }
      salary_range { "$#{rand(50..150)}k - $#{rand(150..300)}k" }
      apply_url { Faker::Internet.url(host: "jobs.example.com") }
      expires_at { 30.days.from_now }
    end

    trait :service do
      directory
      listing_type { 2 }
    end

    trait :featured do
      featured_from { 1.day.ago }
      featured_until { 30.days.from_now }
      association :featured_by, factory: :user
    end

    trait :featured_expired do
      featured_from { 30.days.ago }
      featured_until { 1.day.ago }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :with_affiliate do
      affiliate_url_template { "https://affiliate.example.com?url={url}&ref=curated" }
      affiliate_attribution { { source: "curated", medium: "affiliate" } }
    end

    trait :paid do
      paid { true }
      payment_reference { "pay_#{SecureRandom.hex(8)}" }
    end

    # ---------------------------------------------------------------
    # Common traits
    # ---------------------------------------------------------------

    trait :unpublished do
      published_at { nil }
    end

    trait :published do
      published_at { 1.hour.ago }
    end

    trait :recent do
      published_at { 1.hour.ago }
    end

    trait :old do
      published_at { 1.week.ago }
    end

    trait :with_engagement do
      transient do
        upvotes { 10 }
        comments { 5 }
      end

      after(:create) do |entry, evaluator|
        entry.update_columns(
          upvotes_count: evaluator.upvotes,
          comments_count: evaluator.comments
        )
      end
    end

    trait :high_engagement do
      after(:create) { |e| e.update_columns(upvotes_count: 100, comments_count: 50) }
    end

    trait :low_engagement do
      after(:create) { |e| e.update_columns(upvotes_count: 0, comments_count: 0) }
    end

    trait :hidden do
      transient do
        hidden_by_user { nil }
      end

      after(:create) do |entry, evaluator|
        admin = evaluator.hidden_by_user || create(:user, :admin)
        entry.update_columns(hidden_at: Time.current, hidden_by_id: admin.id)
      end
    end

    trait :comments_locked do
      transient do
        locked_by_user { nil }
      end

      after(:create) do |entry, evaluator|
        admin = evaluator.locked_by_user || create(:user, :admin)
        entry.update_columns(comments_locked_at: Time.current, comments_locked_by_id: admin.id)
      end
    end

    trait :scheduled do
      published_at { nil }
      scheduled_for { 1.day.from_now }
    end

    trait :due_for_publishing do
      published_at { nil }
      scheduled_for { 1.hour.ago }
    end
  end
end
