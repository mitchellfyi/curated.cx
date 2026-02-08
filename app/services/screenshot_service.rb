# frozen_string_literal: true

# Service for capturing page screenshots using an external screenshot API.
# Captures a screenshot for a given URL and returns the screenshot URL.
#
# Supports fallback to OG image when screenshot capture fails.
#
# Configuration:
#   Set SCREENSHOT_API_KEY and optionally SCREENSHOT_API_URL environment variables.
#   Default API endpoint: https://shot.screenshotapi.net/screenshot
#
# Usage:
#   result = ScreenshotService.capture("https://example.com")
#   result[:screenshot_url]  # => "https://..."
#   result[:captured_at]     # => Time
#
class ScreenshotService
  class ScreenshotError < StandardError; end
  class ConfigurationError < ScreenshotError; end

  DEFAULT_API_URL = "https://shot.screenshotapi.net/screenshot"
  DEFAULT_VIEWPORT_WIDTH = 1280
  DEFAULT_VIEWPORT_HEIGHT = 800
  THUMBNAIL_WIDTH = 640
  TIMEOUT = 30

  def self.capture(url, width: DEFAULT_VIEWPORT_WIDTH, height: DEFAULT_VIEWPORT_HEIGHT)
    new(url, width: width, height: height).capture
  end

  def self.capture_for_content_item(content_item)
    new(content_item.url_canonical).capture_for_content_item(content_item)
  end

  def initialize(url, width: DEFAULT_VIEWPORT_WIDTH, height: DEFAULT_VIEWPORT_HEIGHT)
    @url = url
    @width = width
    @height = height
  end

  def capture
    validate_configuration!

    screenshot_url = request_screenshot
    {
      screenshot_url: screenshot_url,
      captured_at: Time.current
    }
  rescue ConfigurationError
    raise
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise ScreenshotError, "Screenshot request timed out: #{e.message}"
  rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
    raise ScreenshotError, "Connection failed: #{e.message}"
  rescue StandardError => e
    raise ScreenshotError, "Screenshot capture failed: #{e.message}"
  end

  def capture_for_content_item(content_item)
    result = capture
    content_item.update!(
      screenshot_url: result[:screenshot_url],
      screenshot_captured_at: result[:captured_at]
    )
    result
  rescue ScreenshotError => e
    Rails.logger.warn("ScreenshotService: Failed for content_item #{content_item.id}: #{e.message}")
    fallback_to_og_image(content_item)
    nil
  end

  private

  def validate_configuration!
    return if api_key.present?

    raise ConfigurationError, "SCREENSHOT_API_KEY is not configured"
  end

  def request_screenshot
    uri = build_api_uri
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    handle_response(response)
  end

  def build_api_uri
    params = {
      token: api_key,
      url: @url,
      width: @width,
      height: @height,
      thumbnail_width: THUMBNAIL_WIDTH,
      output: "image",
      fresh: "true"
    }

    uri = URI.parse(api_url)
    uri.query = URI.encode_www_form(params)
    uri
  end

  def handle_response(response)
    case response
    when Net::HTTPSuccess
      parse_screenshot_url(response)
    when Net::HTTPClientError
      raise ScreenshotError, "API client error: #{response.code} #{response.message}"
    when Net::HTTPServerError
      raise ScreenshotError, "API server error: #{response.code} #{response.message}"
    else
      raise ScreenshotError, "Unexpected response: #{response.code} #{response.message}"
    end
  end

  def parse_screenshot_url(response)
    content_type = response["Content-Type"].to_s

    if content_type.include?("application/json")
      data = JSON.parse(response.body)
      data["screenshot"] || data["url"] || data["image"]
    else
      # Some APIs return the image directly via redirect or as image URL in Location header
      response["Location"] || raise(ScreenshotError, "No screenshot URL in response")
    end
  rescue JSON::ParserError
    raise ScreenshotError, "Invalid JSON response from screenshot API"
  end

  def fallback_to_og_image(content_item)
    return unless content_item.og_image_url.present? && content_item.screenshot_url.blank?

    Rails.logger.info("ScreenshotService: Using OG image fallback for content_item #{content_item.id}")
    content_item.update!(
      screenshot_url: content_item.og_image_url,
      screenshot_captured_at: Time.current
    )
  end

  def api_key
    ENV.fetch("SCREENSHOT_API_KEY", nil)
  end

  def api_url
    ENV.fetch("SCREENSHOT_API_URL", DEFAULT_API_URL)
  end
end
