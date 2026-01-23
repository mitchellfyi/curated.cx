# frozen_string_literal: true

# Job to fetch and parse RSS/Atom feeds
class FetchRssJob < ApplicationJob
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
    unless source.enabled? && source.rss?
      source.update_run_status("skipped")
      return
    end

    # Get feed URL from config
    feed_url = source.config["url"] || source.config[:url]
    raise "RSS feed URL not configured" if feed_url.blank?

    # Fetch and parse feed
    feed = fetch_and_parse_feed(feed_url)

    # Extract URLs from feed entries
    urls = extract_urls_from_feed(feed)

    # Enqueue upsert jobs for each URL
    category = find_or_create_category(site, tenant, "news")
    urls.each do |url|
      UpsertListingsJob.perform_later(tenant.id, category.id, url, source_id: source.id)
    end

    # Update source status
    source.update_run_status("success")
  rescue StandardError => e
    source.update_run_status("error: #{e.message}")
    log_job_error(e, source_id: source_id)
    raise
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def fetch_and_parse_feed(feed_url)
    require "feedjira"

    response = fetch_url(feed_url)
    Feedjira.parse(response.body)
  end

  def fetch_url(url)
    require "net/http"
    require "uri"

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri.path)
    request["User-Agent"] = "Mozilla/5.0 (compatible; Curated.cx Feed Fetcher)"

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Feed fetch failed: #{response.code} #{response.message}"
    end

    response
  end

  def extract_urls_from_feed(feed)
    urls = []

    feed.entries.each do |entry|
      url = entry.url || entry.entry_id
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
