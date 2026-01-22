# frozen_string_literal: true

# Job to fetch news from Google News via SerpAPI
class FetchSerpApiNewsJob < ApplicationJob
  queue_as :ingestion

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(source_id)
    source = Source.find(source_id)
    tenant = source.tenant
    site = source.site

    # Set tenant context for the job
    Current.tenant = tenant
    Current.site = site

    # Verify source is enabled and correct kind
    unless source.enabled? && source.serp_api_google_news?
      source.update_run_status("skipped")
      return
    end

    # Get API key from source config
    api_key = source.config["api_key"] || source.config[:api_key]
    raise "SerpAPI key not configured" if api_key.blank?

    # Get query and other params from config
    query = source.config["query"] || source.config[:query] || ""
    location = source.config["location"] || source.config[:location] || "United States"
    language = source.config["language"] || source.config[:language] || "en"

    # Call SerpAPI
    results = fetch_from_serp_api(api_key, query, location, language)

    # Extract URLs from results
    urls = extract_urls_from_results(results)

    # Enqueue upsert jobs for each URL
    category = find_or_create_category(site, tenant, "news")
    urls.each do |url|
      UpsertListingsJob.perform_later(tenant.id, category.id, url, source_id: source.id)
    end

    # Update source status
    source.update_run_status("success")
  rescue StandardError => e
    source.update_run_status("error: #{e.message}")
    raise
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def fetch_from_serp_api(api_key, query, location, language)
    require "net/http"
    require "json"
    require "uri"

    uri = URI("https://serpapi.com/search.json")
    params = {
      engine: "google_news",
      api_key: api_key,
      q: query,
      location: location,
      hl: language
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      raise "SerpAPI request failed: #{response.code} #{response.message}"
    end

    JSON.parse(response.body)
  end

  def extract_urls_from_results(results)
    urls = []
    news_results = results.dig("news_results") || []

    news_results.each do |result|
      url = result["link"]
      urls << url if url.present?
    end

    urls
  end

  def find_or_create_category(site, tenant, category_key)
    category = Category.find_by(site: site, key: category_key)
    return category if category

    Category.create!(
      tenant: tenant,
      site: site,
      key: category_key,
      name: category_key.humanize,
      allow_paths: true,
      shown_fields: {}
    )
  end
end
