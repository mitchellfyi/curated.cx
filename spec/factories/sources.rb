# frozen_string_literal: true

# == Schema Information
#
# Table name: sources
#
#  id          :bigint           not null, primary key
#  config      :jsonb            not null
#  enabled     :boolean          default(TRUE), not null
#  kind        :integer          not null
#  last_run_at :datetime
#  last_status :string
#  name        :string           not null
#  schedule    :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  site_id     :bigint           not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_sources_on_site_id                (site_id)
#  index_sources_on_site_id_and_name       (site_id,name) UNIQUE
#  index_sources_on_tenant_id              (tenant_id)
#  index_sources_on_tenant_id_and_enabled  (tenant_id,enabled)
#  index_sources_on_tenant_id_and_kind     (tenant_id,kind)
#  index_sources_on_tenant_id_and_name     (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
FactoryBot.define do
  factory :source do
    association :site
    # tenant is set from site in callback
    sequence(:name) { |n| "Source #{n}" }
    kind { :rss }
    enabled { true }
    config { {} }
    schedule { { interval_seconds: 3600 } }

    trait :serp_api_google_news do
      kind { :serp_api_google_news }
      name { "Google News via SerpAPI" }
      config do
        {
          api_key: "test_api_key",
          query: "AI news",
          location: "United States",
          language: "en"
        }
      end
    end

    trait :rss do
      kind { :rss }
      name { "RSS Feed" }
      config do
        {
          url: "https://example.com/feed.xml"
        }
      end
    end

    trait :api do
      kind { :api }
      name { "API Source" }
      config do
        {
          endpoint: "https://api.example.com/v1/news"
        }
      end
    end

    trait :web_scraper do
      kind { :web_scraper }
      name { "Web Scraper" }
      config do
        {
          url: "https://example.com/news",
          selectors: {
            links: "a.article-link"
          }
        }
      end
    end

    trait :disabled do
      enabled { false }
    end

    trait :due_for_run do
      last_run_at { 2.hours.ago }
    end

    trait :recently_run do
      last_run_at { 10.minutes.ago }
    end
  end
end
