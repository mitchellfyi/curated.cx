# frozen_string_literal: true

# Service for extracting rich metadata from URLs using MetaInspector.
# Provides title, description, OG image, author, publish date, favicon,
# word count estimation, read time, and domain extraction.
class LinkEnrichmentService
  class EnrichmentError < StandardError; end

  TIMEOUT = 15
  USER_AGENT = "Mozilla/5.0 (compatible; Curated.cx Link Enrichment Bot)"
  WORDS_PER_MINUTE = 200

  def self.enrich(url)
    new(url).enrich
  end

  def initialize(url)
    @url = url
  end

  def enrich
    page = fetch_page
    word_count = estimate_word_count(page)

    {
      title: page.best_title.presence,
      description: page.best_description.presence,
      og_image_url: page.images.best.presence,
      author_name: extract_author(page),
      published_at: extract_published_at(page),
      word_count: word_count,
      read_time_minutes: calculate_read_time(word_count),
      domain: page.host,
      favicon_url: page.meta_tags.dig("name", "msapplication-TileImage")&.first.presence ||
                   extract_favicon(page)
    }.compact
  rescue MetaInspector::TimeoutError, MetaInspector::RequestError => e
    raise EnrichmentError, "Failed to fetch URL: #{e.message}"
  rescue StandardError => e
    Rails.logger.warn("LinkEnrichmentService error for #{@url}: #{e.message}")
    raise EnrichmentError, "Enrichment failed: #{e.message}"
  end

  private

  def fetch_page
    require "metainspector"

    MetaInspector.new(
      @url,
      timeout: TIMEOUT,
      retries: 1,
      headers: {
        "User-Agent" => USER_AGENT
      }
    )
  end

  def estimate_word_count(page)
    text = page.parsed&.css("body")&.text.to_s
    words = text.split(/\s+/).reject(&:blank?)
    words.size
  rescue StandardError
    nil
  end

  def calculate_read_time(word_count)
    return nil unless word_count && word_count > 0

    (word_count.to_f / WORDS_PER_MINUTE).ceil
  end

  def extract_author(page)
    # Try meta author tag first, then OG article:author
    author = page.meta_tags.dig("name", "author")&.first
    author.presence || page.meta_tags.dig("property", "article:author")&.first.presence
  rescue StandardError
    nil
  end

  def extract_published_at(page)
    date_str = page.meta_tags.dig("property", "article:published_time")&.first
    date_str.presence || page.meta_tags.dig("name", "date")&.first.presence
  rescue StandardError
    nil
  end

  def extract_favicon(page)
    # MetaInspector provides favicon via link tags
    favicon_links = page.parsed&.css('link[rel~="icon"], link[rel="shortcut icon"]')
    href = favicon_links&.first&.[]("href")
    return nil unless href.present?

    # Resolve relative URLs
    if href.start_with?("http")
      href
    else
      URI.join(@url, href).to_s
    end
  rescue StandardError
    nil
  end
end
