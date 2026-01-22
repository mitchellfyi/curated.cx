# frozen_string_literal: true

# Job to scrape metadata from URLs using MetaInspector
class ScrapeMetadataJob < ApplicationJob
  queue_as :scraping

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

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
    listing.update!(
      title: page.title.presence || listing.title,
      description: page.description.presence || listing.description,
      image_url: page.images.best.presence || listing.image_url,
      site_name: page.host.presence || listing.site_name,
      body_html: page.body.presence,
      body_text: extract_text_from_html(page.body),
      published_at: extract_published_at(page) || listing.published_at
    )

    listing
  rescue StandardError => e
    Rails.logger.error("Error in ScrapeMetadataJob for listing #{listing_id}: #{e.class} - #{e.message}")
    # Don't re-raise - we don't want to block the job queue for scraping failures
    nil
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def fetch_page_metadata(url)
    require "metainspector"

    page = MetaInspector.new(
      url,
      timeout: 20,
      retries: 2,
      headers: {
        "User-Agent" => "Mozilla/5.0 (compatible; Curated.cx Metadata Scraper)"
      }
    )

    page
  rescue MetaInspector::TimeoutError, MetaInspector::RequestError => e
    Rails.logger.warn("Failed to fetch metadata for #{url}: #{e.message}")
    raise
  end

  def extract_text_from_html(html)
    return nil unless html.present?

    require "nokogiri"
    doc = Nokogiri::HTML(html)
    doc.text.strip
  rescue StandardError => e
    Rails.logger.warn("Failed to extract text from HTML: #{e.message}")
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
    nil
  end

  def extract_json_ld(html)
    require "nokogiri"
    require "json"

    doc = Nokogiri::HTML(html)
    script_tags = doc.css('script[type="application/ld+json"]')

    script_tags.each do |script|
      data = JSON.parse(script.text)
      return data if data["datePublished"] || data[:datePublished]
    rescue JSON::ParserError
      next
    end

    nil
  rescue StandardError
    nil
  end
end
