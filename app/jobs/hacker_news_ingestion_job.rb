# frozen_string_literal: true

# Job to fetch stories from Hacker News via the Algolia API and store as feed Entries.
# Uses the free HN Algolia API (no authentication required).
class HackerNewsIngestionJob < ApplicationJob
  include WorkflowPausable

  self.workflow_type = :hacker_news_ingestion

  queue_as :ingestion

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  HN_BASE_URL = "https://hn.algolia.com/api/v1"

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
    unless @source.enabled? && @source.hacker_news?
      @source.update_run_status("skipped")
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
    query = config_value("query") || ""
    tags = config_value("tags") || "story"

    # Call HN Algolia API
    results = fetch_from_hacker_news(query, tags)

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

  def fetch_from_hacker_news(query, tags)
    require "net/http"
    require "json"
    require "uri"

    uri = URI("#{HN_BASE_URL}/search")
    params = { query: query, tags: tags }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      raise ExternalServiceError, "Hacker News API request failed: #{response.code} #{response.message}"
    end

    JSON.parse(response.body)
  end

  def process_results(results)
    stats = { created: 0, updated: 0, failed: 0 }
    hits = results.dig("hits") || []
    max_results = config_value("max_results")&.to_i || 100

    # Limit results to max_results
    hits = hits.first(max_results)

    hits.each do |hit|
      process_single_result(hit, stats)
    end

    stats
  end

  def process_single_result(hit, stats)
    # Use the story URL if available, otherwise link to the HN discussion
    url = hit["url"].presence || hn_discussion_url(hit["objectID"])
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

    entry.assign_attributes(
      url_raw: url,
      title: hit["title"],
      description: build_description(hit),
      published_at: parse_date(hit["created_at"]),
      raw_payload: hit,
      tags: extract_tags(hit)
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

    Time.zone.parse(date_string)
  rescue ArgumentError
    nil
  end

  def extract_tags(hit)
    tags = [ "source:hacker-news" ]

    # Add HN-specific tags from _tags field
    hn_tags = hit["_tags"] || []
    hn_tags.each do |tag|
      tags << "hn:#{tag}" if tag.present?
    end

    tags
  end

  def build_description(hit)
    parts = []
    parts << "#{hit['points']} points" if hit["points"]
    parts << "#{hit['num_comments']} comments" if hit["num_comments"]
    parts << "by #{hit['author']}" if hit["author"]
    parts.any? ? parts.join(" | ") : nil
  end

  def hn_discussion_url(object_id)
    return nil if object_id.blank?

    "https://news.ycombinator.com/item?id=#{object_id}"
  end
end
