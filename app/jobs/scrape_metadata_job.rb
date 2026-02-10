# frozen_string_literal: true

# Job to scrape metadata from URLs using MetaInspector
class ScrapeMetadataJob < ApplicationJob
  queue_as :scraping

  # Retry on transient network errors (timeouts, connection failures)
  retry_on ExternalServiceError, wait: :polynomially_longer, attempts: 3

  # Discard if the entry was deleted (discard_on ActiveRecord::RecordNotFound)

  def perform(entry_id)
    entry = Entry.find(entry_id)
    Current.tenant = entry.tenant
    Current.site = entry.site

    page = fetch_page_metadata(entry.url_canonical)
    html_content = page.to_s.presence
    entry.update!(
      title: page.title.presence || entry.title,
      description: page.description.presence || entry.description,
      image_url: page.images.best.presence || entry.image_url,
      site_name: page.host.presence || entry.site_name,
      body_html: html_content,
      body_text: extract_text_from_html(html_content),
      published_at: extract_published_at(page) || entry.published_at
    )

    entry
  rescue ExternalServiceError
    raise
  rescue StandardError => e
    log_job_error(e, entry_id: entry_id)
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
