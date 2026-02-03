# frozen_string_literal: true

# Job to fetch job listings from Google Jobs via SerpAPI and store as Listings.
# Uses the ingestion architecture with ImportRun tracking.
class SerpApiJobsIngestionJob < ApplicationJob
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
    unless @source.enabled? && @source.serp_api_google_jobs?
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

    # Get query and other params from config
    query = config_value("query") || ""
    location = config_value("location") || "United States"

    # Call SerpAPI
    results = fetch_from_serp_api(api_key, query, location)

    # Parse results and create Listings
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

  def fetch_from_serp_api(api_key, query, location)
    require "net/http"
    require "json"
    require "uri"

    uri = URI("https://serpapi.com/search.json")
    params = {
      engine: "google_jobs",
      api_key: api_key,
      q: query,
      location: location
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
    jobs_results = results.dig("jobs_results") || []
    max_results = config_value("max_results")&.to_i || 50

    # Limit results to max_results
    jobs_results = jobs_results.first(max_results)

    jobs_results.each do |result|
      process_single_result(result, stats)
    end

    stats
  end

  def process_single_result(result, stats)
    # Get apply URL - prefer direct link, fallback to first apply option
    apply_url = result["apply_options"]&.first&.dig("link") || result["related_links"]&.first&.dig("link")
    return if apply_url.blank?

    # Canonicalize the URL
    canonical_url = UrlCanonicaliser.canonicalize(apply_url)

    # Find or create jobs category
    category = find_or_create_jobs_category

    # Find or initialize Listing by canonical URL (deduplication)
    listing = Listing.find_or_initialize_by(
      site: @site,
      url_canonical: canonical_url
    )

    # Determine if this is a new record
    is_new = listing.new_record?

    # Extract salary if available
    salary = result.dig("detected_extensions", "salary") ||
             result.dig("salary_info", "salary_range")

    # Update attributes from SerpAPI result
    listing.assign_attributes(
      tenant: @tenant,
      category: category,
      source: @source,
      url_raw: apply_url,
      listing_type: :job,
      title: result["title"],
      company: result["company_name"],
      location: result["location"],
      description: result["description"],
      salary_range: salary,
      apply_url: apply_url,
      metadata: {
        posted_at: result.dig("detected_extensions", "posted_at"),
        schedule_type: result.dig("detected_extensions", "schedule_type"),
        work_from_home: result.dig("detected_extensions", "work_from_home"),
        via: result["via"]
      },
      published_at: Time.current
    )

    if listing.save
      is_new ? stats[:created] += 1 : stats[:updated] += 1
    else
      stats[:failed] += 1
      log_job_warning(
        "Failed to save Listing",
        url: apply_url,
        errors: listing.errors.full_messages
      )
    end
  rescue UrlCanonicaliser::InvalidUrlError => e
    stats[:failed] += 1
    log_job_warning("Invalid URL", url: apply_url, error: e.message)
  rescue StandardError => e
    stats[:failed] += 1
    log_job_warning("Failed to process result", error: e.message)
  end

  def find_or_create_jobs_category
    category = Category.find_by(site: @site, key: "jobs")
    return category if category

    Category.create!(
      tenant: @tenant,
      site: @site,
      key: "jobs",
      name: "Jobs",
      allow_paths: true,
      shown_fields: {
        company: true,
        location: true,
        salary_range: true,
        apply_url: true
      }
    )
  end

  def handle_failure(error)
    @import_run&.mark_failed!(error.message)
    @source.update_run_status("error: #{error.message}")
    log_job_error(error, source_id: @source.id, import_run_id: @import_run&.id)
  end

  def config_value(key)
    @source.config[key] || @source.config[key.to_sym]
  end
end
