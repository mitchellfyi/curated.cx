# frozen_string_literal: true

# Service for extracting Open Graph metadata from URLs for link previews
class LinkPreviewService
  class ExtractionError < StandardError; end

  TIMEOUT = 15
  USER_AGENT = "Mozilla/5.0 (compatible; Curated.cx Link Preview Bot)"

  def self.extract(url)
    new(url).extract
  end

  def initialize(url)
    @url = url
  end

  def extract
    page = fetch_metadata
    {
      "url" => page.url,
      "title" => page.title.presence,
      "description" => page.description.presence,
      "image" => page.images.best.presence,
      "site_name" => extract_site_name(page)
    }.compact
  rescue MetaInspector::TimeoutError, MetaInspector::RequestError => e
    raise ExtractionError, "Failed to fetch URL: #{e.message}"
  rescue StandardError => e
    Rails.logger.warn("LinkPreviewService error for #{@url}: #{e.message}")
    raise ExtractionError, "Extraction failed: #{e.message}"
  end

  private

  def fetch_metadata
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

  def extract_site_name(page)
    # Try OG site_name first, then fall back to host
    og_site_name = page.meta_tags.dig("property", "og:site_name")&.first
    og_site_name.presence || page.host
  end
end
