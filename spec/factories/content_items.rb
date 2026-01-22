# frozen_string_literal: true

# == Schema Information
#
# Table name: content_items
#
#  id             :bigint           not null, primary key
#  description    :text
#  extracted_text :text
#  published_at   :datetime
#  raw_payload    :jsonb            not null
#  summary        :text
#  tags           :jsonb            not null
#  title          :string
#  url_canonical  :string           not null
#  url_raw        :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#  source_id      :bigint           not null
#
# Indexes
#
#  index_content_items_on_published_at               (published_at)
#  index_content_items_on_site_id                    (site_id)
#  index_content_items_on_site_id_and_url_canonical  (site_id,url_canonical) UNIQUE
#  index_content_items_on_source_id                  (source_id)
#  index_content_items_on_source_id_and_created_at   (source_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#
FactoryBot.define do
  factory :content_item do
    association :source
    site { source.site }
    sequence(:url_raw) { |n| "https://example.com/article-#{n}?utm_source=test" }
    url_canonical { url_raw } # Will be normalized by callback
    title { Faker::Lorem.sentence }
    description { Faker::Lorem.paragraph }
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
    published_at { 1.hour.ago }

    trait :unpublished do
      published_at { nil }
    end
  end
end
