# frozen_string_literal: true

# Job to fetch Reddit posts via SerpAPI and store as feed Entries.
# Uses the Reddit Search API: https://serpapi.com/reddit-search-api
class SerpApiRedditIngestionJob < ApplicationJob
  include WorkflowPausable

  self.workflow_type = :serp_api_ingestion

  queue_as :ingestion

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(source_id)
    @source = Source.find(source_id)
    @site = @source.site
    @tenant = @site.tenant

    # Set tenant context for the job
    Current.tenant = @tenant
    Current.site = @site

    # Check if workflow is paused
    return if workflow_paused?(source: @source, tenant: @tenant)

    # Verify source is enabled and correct kind
    unless @source.enabled? && @source.reddit_search?
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

    # Check hourly limit (to spread usage throughout the day)
    unless SerpApiGlobalRateLimiter.allow_this_hour?
      @source.update_run_status("hourly_rate_limited")
      log_job_info("Hourly SerpAPI limit reached, will retry next hour",
                   source_id: source_id,
                   stats: SerpApiGlobalRateLimiter.usage_stats)
      return
    end

    # Check per-source rate limit
    rate_limiter = SerpApiRateLimiter.new(@source)
    unless rate_limiter.allow?
      @source.update_run_status("per_source_rate_limited")
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

    # Get search query and params from config
    query = config_value("query") || ""
    raise ConfigurationError, "Search query not configured" if query.blank?

    # Call SerpAPI Reddit Search endpoint
    results = fetch_from_serp_api(api_key, query)

    # Parse results and create feed Entries
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

  def fetch_from_serp_api(api_key, query)
    require "net/http"
    require "json"
    require "uri"

    uri = URI("https://serpapi.com/search.json")
    params = {
      engine: "reddit_search",
      api_key: api_key,
      q: query
    }

    # Add optional subreddit filter
    subreddit = config_value("subreddit")
    params[:subreddit] = subreddit if subreddit.present?

    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      raise ExternalServiceError, "SerpAPI Reddit request failed: #{response.code} #{response.message}"
    end

    JSON.parse(response.body)
  end

  def process_results(results)
    stats = { created: 0, updated: 0, failed: 0 }
    organic_results = results.dig("organic_results") || []
    max_results = config_value("max_results")&.to_i || 20

    # Limit results to max_results
    organic_results = organic_results.first(max_results)

    organic_results.each do |result|
      process_single_result(result, stats)
    end

    stats
  end

  def process_single_result(result, stats)
    url = result["link"]
    return if url.blank?

    # For self-posts (link points to Reddit), use the Reddit URL directly
    # For link posts (external URL), use the external link
    is_self_post = url.include?("reddit.com/r/")

    # Canonicalize the URL
    canonical_url = UrlCanonicaliser.canonicalize(url)

    # Find or initialize feed Entry by canonical URL (deduplication)
    entry = Entry.find_or_initialize_by_canonical_url(
      site: @site,
      url_canonical: canonical_url,
      source: @source,
      entry_kind: "feed"
    )

    is_new = entry.new_record?

    entry.assign_attributes(
      url_raw: url,
      title: result["title"],
      description: result["snippet"],
      og_image_url: result["thumbnail"],
      author_name: result["author"],
      raw_payload: build_raw_payload(result, is_self_post),
      tags: extract_tags(result, is_self_post)
    )

    if entry.save
      is_new ? stats[:created] += 1 : stats[:updated] += 1
    else
      stats[:failed] += 1
      log_job_warning(
        "Failed to save Entry",
        url: url,
        errors: entry.errors.full_messages
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

  def extract_tags(result, is_self_post)
    tags = []

    # Add source tag
    tags << "source:reddit"

    # Add subreddit as a tag
    subreddit = result["subreddit"]
    if subreddit.present?
      # Normalize subreddit name (remove r/ prefix if present)
      sub_name = subreddit.sub(%r{\Ar/}, "").downcase
      tags << "subreddit:#{sub_name}"
    end

    # Tag self-posts vs link posts
    tags << (is_self_post ? "reddit:self_post" : "reddit:link_post")

    tags
  end

  def build_raw_payload(result, is_self_post)
    result.merge(
      "_reddit_metadata" => {
        "subreddit" => result["subreddit"],
        "author" => result["author"],
        "upvotes" => result["upvotes"],
        "comment_count" => result["comments"],
        "is_self_post" => is_self_post
      }.compact
    )
  end
end
