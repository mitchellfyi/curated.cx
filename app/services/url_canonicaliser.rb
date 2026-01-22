# frozen_string_literal: true

# Service to canonicalize URLs by:
# - Normalizing scheme and host
# - Removing tracking parameters
# - Normalizing paths
# - Resolving canonical links from HTML (optional)
class UrlCanonicaliser
  TRACKING_PARAMS = %w[
    utm_source utm_medium utm_campaign utm_term utm_content
    fbclid gclid mc_cid mc_eid
    ref source campaign
  ].freeze

  class InvalidUrlError < StandardError; end

  def self.canonicalize(url_raw, html_content: nil)
    new(url_raw, html_content: html_content).canonicalize
  end

  def initialize(url_raw, html_content: nil)
    @url_raw = url_raw.to_s.strip
    @html_content = html_content
  end

  def canonicalize
    return nil if @url_raw.blank?

    # Parse and normalize the URL
    uri = parse_uri

    # Check for canonical link in HTML if provided
    canonical_url = extract_canonical_link(uri)
    uri = parse_uri(canonical_url) if canonical_url

    # Normalize scheme
    uri.scheme = uri.scheme.downcase

    # Normalize host
    uri.host = uri.host.downcase

    # Remove tracking parameters
    remove_tracking_params(uri)

    # Normalize path
    normalize_path(uri)

    uri.to_s
  rescue URI::InvalidURIError, ArgumentError => e
    raise InvalidUrlError, "Invalid URL: #{e.message}"
  end

  private

  def parse_uri(url = nil)
    url ||= @url_raw
    uri = URI.parse(url)

    # Validate that it's a proper HTTP/HTTPS URL
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      raise InvalidUrlError, "must be a valid HTTP or HTTPS URL"
    end

    # Ensure it has a host
    unless uri.host.present?
      raise InvalidUrlError, "must include a valid hostname"
    end

    uri
  end

  def extract_canonical_link(fallback_uri)
    return nil unless @html_content.present?

    # Look for <link rel="canonical" href="...">
    canonical_match = @html_content.match(/<link[^>]*rel=["']canonical["'][^>]*href=["']([^"']+)["']/i)
    return nil unless canonical_match

    canonical_url = canonical_match[1]
    # If relative URL, make it absolute
    return URI.join(fallback_uri.to_s, canonical_url).to_s if canonical_url.start_with?("/")

    canonical_url
  end

  def remove_tracking_params(uri)
    return unless uri.query

    params = URI.decode_www_form(uri.query)
    # Remove common tracking parameters
    params = params.reject { |key, _| TRACKING_PARAMS.include?(key.downcase) }
    uri.query = params.empty? ? nil : URI.encode_www_form(params)
  end

  def normalize_path(uri)
    return unless uri.path

    # Remove trailing slash unless it's root
    if uri.path != "/"
      normalized_path = uri.path.gsub(/\/+$/, "")
      # Only set path if it's valid
      begin
        uri.path = normalized_path unless normalized_path.empty?
      rescue URI::InvalidComponentError
        # Keep original path if normalization fails
      end
    end
  end
end
