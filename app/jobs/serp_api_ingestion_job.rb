# frozen_string_literal: true

# Job to fetch news from Google News via SerpAPI and store as ContentItems.
# Uses the new ingestion architecture with ImportRun tracking.
class SerpApiIngestionJob < ApplicationJob
  queue_as :ingestion

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(source_id)
    @source = Source.find(source_id)
    @site = @source.site
    @tenant = @site.tenant

    # Set tenant context for the job
    Current.tenant = @tenant
    Current.site = @site

    # Verify source is enabled and correct kind
    unless @source.enabled? && @source.serp_api_google_news?
      @source.update_run_status("skipped")
      return
    end

    # Check GLOBAL rate limit first (monthly cap across all tenants)
    unless SerpApiGlobalRateLimiter.allow?
      @source.update_run_status("global_rate_limited")
      log_job_warning("Global monthly SerpAPI limit exceeded", 
                      source_id: source_id, 
                      stats: SerpApiGlobalRateLimiter.usage_stats)
      return
    end

    # Check daily soft limit (to spread usage across month)
    unless SerpApiGlobalRateLimiter.allow_today?
      @source.update_run_status("daily_rate_limited")
      log_job_warning("Daily SerpAPI soft limit reached", 
                      source_id: source_id, 
                      stats: SerpApiGlobalRateLimiter.usage_stats)
      return
    end

    # Check per-source rate limit
    rate_limiter = SerpApiRateLimiter.new(@source)
    unless rate_limiter.allow?
      @source.update_run_status("rate_limited")
      log_job_warning("Per-source rate limit exceeded", source_id: source_id, remaining: rate_limiter.remaining)
      return
    end

    # Create ImportRun to track this execution
    @import_run = ImportRun.create_for_source!(@source)

    begin
      execute_ingestion
    rescue StandardError => e
      handle_failure(e)
      raise
    end
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def execute_ingestion
    # Get API key from source config
    api_key = config_value("api_key")
    raise ConfigurationError, "SerpAPI key not configured" if api_key.blank?

    # Get query and other params from config
    query = config_value("query") || ""
    location = config_value("location") || "United States"
    language = config_value("language") || "en"

    # Call SerpAPI
    results = fetch_from_serp_api(api_key, query, location, language)

    # Parse results and create ContentItems
    stats = process_results(results)

    # Mark import run as completed
    @import_run.mark_completed!(
      items_created: stats[:created],
      items_updated: stats[:updated],
      items_failed: stats[:failed]
    )

    # Update source status
    @source.update_run_status("success")
  end

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
      raise ExternalServiceError, "SerpAPI request failed: #{response.code} #{response.message}"
    end

    JSON.parse(response.body)
  end

  def process_results(results)
    stats = { created: 0, updated: 0, failed: 0 }
    news_results = results.dig("news_results") || []
    max_results = config_value("max_results")&.to_i || 100

    # Limit results to max_results
    news_results = news_results.first(max_results)

    news_results.each do |result|
      process_single_result(result, stats)
    end

    stats
  end

  def process_single_result(result, stats)
    url = result["link"]
    return if url.blank?

    # Canonicalize the URL
    canonical_url = UrlCanonicaliser.canonicalize(url)

    # Find or initialize ContentItem by canonical URL (deduplication)
    content_item = ContentItem.find_or_initialize_by_canonical_url(
      site: @site,
      url_canonical: canonical_url,
      source: @source
    )

    # Determine if this is a new record
    is_new = content_item.new_record?

    # Update attributes from SerpAPI result
    content_item.assign_attributes(
      url_raw: url,
      title: result["title"],
      description: result["snippet"],
      published_at: parse_date(result["date"]),
      raw_payload: result,
      tags: extract_tags(result)
    )

    if content_item.save
      is_new ? stats[:created] += 1 : stats[:updated] += 1
    else
      stats[:failed] += 1
      log_job_warning(
        "Failed to save ContentItem",
        url: url,
        errors: content_item.errors.full_messages
      )
    end
  rescue UrlCanonicaliser::InvalidUrlError => e
    stats[:failed] += 1
    log_job_warning("Invalid URL", url: url, error: e.message)
  rescue StandardError => e
    stats[:failed] += 1
    log_job_warning("Failed to process result", url: url, error: e.message)
  end

  def handle_failure(error)
    @import_run&.mark_failed!(error.message)
    @source.update_run_status("error: #{error.message}")
    log_job_error(error, source_id: @source.id, import_run_id: @import_run&.id)
  end

  def config_value(key)
    @source.config[key] || @source.config[key.to_sym]
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    # SerpAPI returns various date formats, try common ones
    Time.zone.parse(date_string)
  rescue ArgumentError
    nil
  end

  def extract_tags(result)
    tags = []

    # Extract source name as a tag
    # SerpAPI returns source as either a string or a hash with "name" key
    source_value = result["source"]
    source_name = source_value.is_a?(Hash) ? source_value["name"] : source_value
    tags << "source:#{source_name.downcase.gsub(/\s+/, '-')}" if source_name.present?

    tags
  end
end
