# frozen_string_literal: true

# Job to fetch and parse RSS/Atom feeds
class FetchRssJob < ApplicationJob
  include JobLogging
  include HttpClient

  queue_as :ingestion

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  class ConfigurationError < StandardError; end

  def perform(source_id)
    @source = Source.find(source_id)
    @site = @source.site
    @tenant = @site.tenant

    set_current_context

    with_job_logging("RSS fetch for source #{source_id}") do
      execute_fetch
    end
  ensure
    clear_current_context
  end

  private

  def execute_fetch
    unless @source.enabled? && @source.rss?
      @source.update_run_status("skipped")
      log_job_info("Source skipped", reason: "disabled or wrong kind")
      return
    end

    feed_url = config_value("url")
    raise ConfigurationError, "RSS feed URL not configured" if feed_url.blank?

    # Create import run for tracking
    @import_run = ImportRun.create_for_source!(@source)

    feed = fetch_and_parse_feed(feed_url)
    urls = extract_urls_from_feed(feed)

    enqueue_upserts(urls)

    @import_run.mark_completed!(
      items_created: urls.size,
      items_updated: 0,
      items_failed: 0
    )
    @source.update_run_status("success")

    log_job_info("RSS fetch completed", urls_found: urls.size)
  rescue StandardError => e
    @import_run&.mark_failed!(e.message)
    @source.update_run_status("error: #{e.message.truncate(100)}")
    raise
  end

  def fetch_and_parse_feed(feed_url)
    require "feedjira"

    response = http_get(feed_url, headers: {
      "User-Agent" => "Mozilla/5.0 (compatible; Curated.cx Feed Fetcher/1.0)",
      "Accept" => "application/rss+xml, application/atom+xml, application/xml, text/xml"
    })

    Feedjira.parse(response.body)
  rescue Feedjira::NoParserAvailable => e
    raise "Unable to parse feed: #{e.message}"
  end

  def extract_urls_from_feed(feed)
    feed.entries.filter_map do |entry|
      entry.url.presence || entry.entry_id.presence
    end.uniq
  end

  def enqueue_upserts(urls)
    return if urls.empty?

    category = find_or_create_category("news")

    urls.each do |url|
      UpsertListingsJob.perform_later(@tenant.id, category.id, url, source_id: @source.id)
    end
  end

  def find_or_create_category(category_key)
    Category.find_by(site: @site, key: category_key) ||
      Category.create!(
        tenant: @tenant,
        site: @site,
        key: category_key,
        name: category_key.humanize,
        allow_paths: true,
        shown_fields: {}
      )
  end

  def config_value(key)
    @source.config[key] || @source.config[key.to_sym]
  end

  def set_current_context
    Current.tenant = @tenant
    Current.site = @site
  end

  def clear_current_context
    Current.tenant = nil
    Current.site = nil
  end
end
