# frozen_string_literal: true

# Job to scrape metadata from URLs using MetaInspector
class ScrapeMetadataJob < ApplicationJob
  queue_as :scraping

  # Retry on transient network errors (timeouts, connection failures)
  retry_on ExternalServiceError, wait: :polynomially_longer, attempts: 3

  # Discard if the listing was deleted before we could scrape
  # (inherited from ApplicationJob via discard_on ActiveRecord::RecordNotFound)

  def perform(listing_id)
    listing = Listing.find(listing_id)
    tenant = listing.tenant
    site = listing.site

    # Set tenant context
    Current.tenant = tenant
    Current.site = site

    # Scrape metadata
    page = fetch_page_metadata(listing.url_canonical)

    # Update listing with metadata
    # MetaInspector provides page.to_s for the raw HTML content
    html_content = page.to_s.presence
    listing.update!(
      title: page.title.presence || listing.title,
      description: page.description.presence || listing.description,
      image_url: page.images.best.presence || listing.image_url,
      site_name: page.host.presence || listing.site_name,
      body_html: html_content,
      body_text: extract_text_from_html(html_content),
      published_at: extract_published_at(page) || listing.published_at
    )

    listing
  rescue ExternalServiceError
    # Let retry_on handle this - just re-raise
    raise
  rescue StandardError => e
    # Log with structured context and re-raise for visibility
    log_job_error(e, listing_id: listing_id)
    raise
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def fetch_page_metadata(url)
    require "metainspector"

    MetaInspector.new(
      url,
      timeout: 20,
      retries: 2,
      headers: {
        "User-Agent" => "Mozilla/5.0 (compatible; Curated.cx Metadata Scraper)"
      }
    )
  rescue MetaInspector::TimeoutError, MetaInspector::RequestError => e
    # Wrap in ExternalServiceError for retry handling
    raise ExternalServiceError.new(
      "Failed to fetch metadata for #{url}: #{e.message}",
      context: { url: url, original_error: e.class.name }
    )
  end

  def extract_text_from_html(html)
    return nil unless html.present?

    require "nokogiri"
    doc = Nokogiri::HTML(html)
    doc.text.strip
  rescue Nokogiri::SyntaxError => e
    # HTML parsing errors are expected for malformed content
    log_job_warning("Failed to extract text from HTML: #{e.message}")
    nil
  end

  def extract_published_at(page)
    return nil unless page.parsed.present?

    # Try to find published date in meta tags
    meta_date = page.meta_tags.dig("property", "article:published_time") ||
                page.meta_tags.dig("property", "og:published_time") ||
                page.meta_tags.dig("name", "date") ||
                page.meta_tags.dig("name", "publishdate")

    return Time.parse(meta_date) if meta_date.present?

    # Try to find in JSON-LD structured data
    json_ld = extract_json_ld(page.parsed)
    if json_ld
      date_published = json_ld["datePublished"] || json_ld[:datePublished]
      return Time.parse(date_published) if date_published.present?
    end

    nil
  rescue ArgumentError, TypeError
    # Invalid date format - return nil
    nil
  end

  def extract_json_ld(doc)
    require "json"

    return nil unless doc.respond_to?(:css)

    script_tags = doc.css('script[type="application/ld+json"]')

    script_tags.each do |script|
      data = JSON.parse(script.text)
      return data if data["datePublished"] || data[:datePublished]
    rescue JSON::ParserError
      # Malformed JSON-LD is common, skip this script tag
      next
    end

    nil
  rescue Nokogiri::SyntaxError
    # HTML parsing errors for malformed content
    nil
  end
end
