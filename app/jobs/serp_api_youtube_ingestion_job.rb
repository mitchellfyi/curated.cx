# frozen_string_literal: true

# Job to fetch videos from YouTube via SerpAPI and store as feed Entries.
# Uses the YouTube Search API: https://serpapi.com/youtube-search-api
class SerpApiYoutubeIngestionJob < ApplicationJob
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
    unless @source.enabled? && @source.serp_api_youtube?
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

    # Call SerpAPI YouTube endpoint
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
      engine: "youtube",
      api_key: api_key,
      search_query: query
    }

    # Add optional filters from config
    params[:sp] = config_value("sp") if config_value("sp").present? # Search params/filters

    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      raise ExternalServiceError, "SerpAPI YouTube request failed: #{response.code} #{response.message}"
    end

    JSON.parse(response.body)
  end

  def process_results(results)
    stats = { created: 0, updated: 0, failed: 0 }
    video_results = results.dig("video_results") || []
    max_results = config_value("max_results")&.to_i || 20

    # Limit results to max_results
    video_results = video_results.first(max_results)

    video_results.each do |result|
      process_single_result(result, stats)
    end

    stats
  end

  def process_single_result(result, stats)
    url = result["link"]
    return if url.blank?

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
    channel = result["channel"] || {}

    entry.assign_attributes(
      url_raw: url,
      title: result["title"],
      description: result["description"],
      published_at: parse_date(result["published_date"]),
      raw_payload: result,
      tags: extract_tags(result),
      metadata: build_metadata(result, channel)
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

  def parse_date(date_string)
    return nil if date_string.blank?

    # YouTube returns relative dates like "18 hours ago", "2 days ago", etc.
    case date_string.downcase
    when /(\d+)\s*hour/
      $1.to_i.hours.ago
    when /(\d+)\s*day/
      $1.to_i.days.ago
    when /(\d+)\s*week/
      $1.to_i.weeks.ago
    when /(\d+)\s*month/
      $1.to_i.months.ago
    when /(\d+)\s*year/
      $1.to_i.years.ago
    when /streamed/i
      # "Streamed X ago" - extract the time part
      parse_date(date_string.sub(/streamed\s*/i, ""))
    else
      # Try direct parsing
      Time.zone.parse(date_string) rescue nil
    end
  end

  def extract_tags(result)
    tags = []

    # Add content type tag
    tags << "content_type:video"

    # Extract channel name as a tag
    channel_name = result.dig("channel", "name")
    tags << "channel:#{channel_name.downcase.gsub(/\s+/, '-')}" if channel_name.present?

    # Add verified tag if channel is verified
    tags << "verified" if result.dig("channel", "verified")

    # Add any extensions as tags (e.g., "4K", "CC", "New")
    extensions = result["extensions"] || []
    extensions.each do |ext|
      tags << "extension:#{ext.downcase.gsub(/\s+/, '-')}"
    end

    tags
  end

  def build_metadata(result, channel)
    {
      video_id: extract_video_id(result["link"]),
      channel_name: channel["name"],
      channel_link: channel["link"],
      channel_verified: channel["verified"],
      views: result["views"],
      length: result["length"],
      thumbnail: result.dig("thumbnail", "static") || result["thumbnail"]
    }.compact
  end

  def extract_video_id(url)
    return nil if url.blank?

    # Extract video ID from YouTube URL
    if url.include?("watch?v=")
      url.split("watch?v=").last.split("&").first
    elsif url.include?("youtu.be/")
      url.split("youtu.be/").last.split("?").first
    end
  end
end
