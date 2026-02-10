# frozen_string_literal: true

# == Schema Information
#
# Table name: entries
#
#  id                         :bigint           not null, primary key
#  affiliate_attribution      :jsonb            not null
#  affiliate_url_template     :text
#  ai_suggested_tags          :jsonb            not null
#  ai_summaries               :jsonb            not null
#  ai_summary                 :text
#  ai_tags                    :jsonb            not null
#  apply_url                  :text
#  audience_tags              :string           default([]), is an Array
#  author_name                :string
#  body_html                  :text
#  body_text                  :text
#  comments_count             :integer          default(0), not null
#  comments_locked_at         :datetime
#  company                    :string
#  content_type               :string
#  description                :text
#  domain                     :string
#  editorialised_at           :datetime
#  enriched_at                :datetime
#  enrichment_errors          :jsonb            not null
#  enrichment_status          :string           default("pending"), not null
#  entry_kind                 :string           default("feed"), not null
#  expires_at                 :datetime
#  extracted_text             :text
#  favicon_url                :string
#  featured_from              :datetime
#  featured_until             :datetime
#  hidden_at                  :datetime
#  image_url                  :text
#  key_takeaways              :jsonb
#  listing_type               :integer          default(0), not null
#  location                   :string
#  metadata                   :jsonb            not null
#  og_image_url               :string
#  paid                       :boolean          default(FALSE), not null
#  payment_reference          :string
#  payment_status             :integer          default("unpaid"), not null
#  published_at               :datetime
#  quality_score              :decimal(3, 1)
#  raw_payload                :jsonb            not null
#  read_time_minutes          :integer
#  salary_range               :string
#  scheduled_for              :datetime
#  screenshot_captured_at     :datetime
#  screenshot_url             :string
#  site_name                  :string
#  summary                    :text
#  tagging_confidence         :decimal(3, 2)
#  tagging_explanation        :jsonb            not null
#  tags                       :jsonb            not null
#  title                      :string
#  topic_tags                 :jsonb            not null
#  upvotes_count              :integer          default(0), not null
#  url_canonical              :string           not null
#  url_raw                    :text             not null
#  why_it_matters             :text
#  word_count                 :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  category_id                :bigint
#  comments_locked_by_id      :bigint
#  featured_by_id             :bigint
#  hidden_by_id               :bigint
#  site_id                    :bigint           not null
#  source_id                  :bigint
#  stripe_checkout_session_id :string
#  stripe_payment_intent_id   :string
#  tenant_id                  :bigint
#
# Indexes
#
#  index_entries_on_category_id                   (category_id)
#  index_entries_on_category_published            (category_id,published_at)
#  index_entries_on_comments_locked_by_id         (comments_locked_by_id)
#  index_entries_on_domain                        (domain)
#  index_entries_on_enrichment_status             (enrichment_status)
#  index_entries_on_entry_kind                    (entry_kind)
#  index_entries_on_featured_by_id                (featured_by_id)
#  index_entries_on_hidden_at                     (hidden_at)
#  index_entries_on_hidden_by_id                  (hidden_by_id)
#  index_entries_on_payment_status                (payment_status)
#  index_entries_on_published_at                  (published_at)
#  index_entries_on_scheduled_for                 (scheduled_for) WHERE (scheduled_for IS NOT NULL)
#  index_entries_on_site_expires_at               (site_id,expires_at)
#  index_entries_on_site_featured_dates           (site_id,featured_from,featured_until)
#  index_entries_on_site_id                       (site_id)
#  index_entries_on_site_id_and_content_type      (site_id,content_type)
#  index_entries_on_site_id_and_editorialised_at  (site_id,editorialised_at)
#  index_entries_on_site_id_and_listing_type      (site_id,listing_type)
#  index_entries_on_site_id_published_at_desc     (site_id,published_at DESC)
#  index_entries_on_site_kind_canonical           (site_id,entry_kind,url_canonical) UNIQUE
#  index_entries_on_source_id                     (source_id)
#  index_entries_on_source_id_and_created_at      (source_id,created_at)
#  index_entries_on_stripe_checkout_session_id    (stripe_checkout_session_id) UNIQUE WHERE (stripe_checkout_session_id IS NOT NULL)
#  index_entries_on_stripe_payment_intent_id      (stripe_payment_intent_id) UNIQUE WHERE (stripe_payment_intent_id IS NOT NULL)
#  index_entries_on_tenant_and_url_canonical      (tenant_id,url_canonical) UNIQUE
#  index_entries_on_tenant_id                     (tenant_id)
#  index_entries_on_tenant_id_and_category_id     (tenant_id,category_id)
#  index_entries_on_tenant_id_and_source_id       (tenant_id,source_id)
#  index_entries_on_tenant_published_created      (tenant_id,published_at,created_at)
#  index_entries_on_tenant_title                  (tenant_id,title)
#  index_entries_on_topic_tags                    (topic_tags) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (comments_locked_by_id => users.id)
#  fk_rails_...  (featured_by_id => users.id)
#  fk_rails_...  (hidden_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
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
      tenant { nil }
      category do
        t = tenant
        if t
          s = t.sites.first || association(:site, tenant: t)
          association(:category, tenant: t, site: s)
        else
          association(:category)
        end
      end
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

    trait :app_listing do
      directory
      sequence(:url_raw) { |n| "https://app-#{n}.example.com" }
      title { Faker::App.name }
      site_name { title }
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
