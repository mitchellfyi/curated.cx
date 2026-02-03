# frozen_string_literal: true

# Utility methods for common operations across the app.
# These are stateless, pure functions that can be used anywhere.
#
# Usage:
#   Utils.truncate_url("https://example.com/very/long/path")
#   Utils.format_number(1234567)
#   Utils.safe_json_parse('{"key": "value"}')
#
module Utils
  module_function

  # URL formatting
  # ================

  # Truncate a URL for display, keeping domain visible
  # @param url [String] Full URL
  # @param max_length [Integer] Maximum total length
  # @return [String] Truncated URL
  def truncate_url(url, max_length: 60)
    return "" if url.blank?

    uri = URI.parse(url.to_s)
    domain = uri.host || url

    return url if url.length <= max_length

    # Keep domain + protocol, truncate path
    prefix = "#{uri.scheme}://#{domain}"
    return prefix.truncate(max_length) if prefix.length >= max_length

    remaining = max_length - prefix.length - 3 # for "..."
    path = uri.path.to_s

    if remaining > 10
      "#{prefix}#{path.truncate(remaining)}"
    else
      prefix.truncate(max_length)
    end
  rescue URI::InvalidURIError
    url.to_s.truncate(max_length)
  end

  # Extract domain from URL
  # @param url [String] Full URL
  # @return [String, nil] Domain or nil if invalid
  def extract_domain(url)
    return nil if url.blank?

    uri = URI.parse(url.to_s)
    uri.host
  rescue URI::InvalidURIError
    nil
  end

  # Number formatting
  # =================

  # Format a large number with abbreviations (1K, 1M, etc.)
  # @param number [Numeric] The number to format
  # @param precision [Integer] Decimal places
  # @return [String] Formatted number
  def format_number(number, precision: 1)
    return "0" if number.nil? || number.zero?

    case number.abs
    when 0...1_000
      number.to_s
    when 1_000...1_000_000
      "#{(number / 1_000.0).round(precision)}K"
    when 1_000_000...1_000_000_000
      "#{(number / 1_000_000.0).round(precision)}M"
    else
      "#{(number / 1_000_000_000.0).round(precision)}B"
    end
  end

  # Format bytes as human readable
  # @param bytes [Integer] Number of bytes
  # @return [String] Formatted size
  def format_bytes(bytes)
    return "0 B" if bytes.nil? || bytes.zero?

    units = ["B", "KB", "MB", "GB", "TB"]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = [exp, units.length - 1].min

    "#{(bytes / 1024.0**exp).round(2)} #{units[exp]}"
  end

  # JSON utilities
  # ==============

  # Safely parse JSON with a default value on failure
  # @param json_string [String] JSON string to parse
  # @param default [Object] Value to return on parse failure
  # @return [Object] Parsed JSON or default
  def safe_json_parse(json_string, default: {})
    return default if json_string.blank?

    JSON.parse(json_string)
  rescue JSON::ParserError
    default
  end

  # Deep symbolize keys recursively
  # @param obj [Object] Hash, Array, or other object
  # @return [Object] Object with symbolized keys
  def deep_symbolize_keys(obj)
    case obj
    when Hash
      obj.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = deep_symbolize_keys(value)
      end
    when Array
      obj.map { |item| deep_symbolize_keys(item) }
    else
      obj
    end
  end

  # String utilities
  # ================

  # Generate a URL-safe slug from text
  # @param text [String] Text to slugify
  # @return [String] URL-safe slug
  def slugify(text)
    return "" if text.blank?

    text.to_s
        .downcase
        .gsub(/[^\w\s-]/, "")      # Remove non-word chars
        .gsub(/[\s_]+/, "-")       # Replace spaces/underscores with hyphens
        .gsub(/^-+|-+$/, "")       # Remove leading/trailing hyphens
        .truncate(100, omission: "")
  end

  # Sanitize filename for safe storage
  # @param filename [String] Original filename
  # @return [String] Sanitized filename
  def sanitize_filename(filename)
    return "file" if filename.blank?

    # Get extension
    ext = File.extname(filename).downcase
    base = File.basename(filename, ext)

    # Sanitize base name
    safe_base = base.to_s
                    .gsub(/[^\w.-]/, "_")
                    .gsub(/_+/, "_")
                    .gsub(/^_|_$/, "")
                    .truncate(100, omission: "")

    safe_base = "file" if safe_base.blank?

    "#{safe_base}#{ext}"
  end

  # Hash a string consistently (for caching, fingerprinting)
  # @param str [String] String to hash
  # @return [String] SHA256 hex digest
  def hash_string(str)
    Digest::SHA256.hexdigest(str.to_s)
  end

  # Date/Time utilities
  # ===================

  # Parse a date string safely
  # @param str [String] Date string
  # @param default [Date, nil] Default value on failure
  # @return [Date, nil] Parsed date or default
  def safe_parse_date(str, default: nil)
    return default if str.blank?

    Date.parse(str.to_s)
  rescue ArgumentError
    default
  end

  # Parse a time string safely
  # @param str [String] Time string
  # @param default [Time, nil] Default value on failure
  # @return [Time, nil] Parsed time or default
  def safe_parse_time(str, default: nil)
    return default if str.blank?

    Time.zone.parse(str.to_s)
  rescue ArgumentError
    default
  end

  # Get relative time description
  # @param time [Time] Time to describe
  # @return [String] Human-readable relative time
  def relative_time(time)
    return "never" if time.nil?

    diff = Time.current - time

    case diff.abs
    when 0...60
      "just now"
    when 60...3600
      "#{(diff / 60).round} minutes ago"
    when 3600...86_400
      "#{(diff / 3600).round} hours ago"
    when 86_400...604_800
      "#{(diff / 86_400).round} days ago"
    when 604_800...2_592_000
      "#{(diff / 604_800).round} weeks ago"
    else
      time.strftime("%b %d, %Y")
    end
  end

  # Array utilities
  # ===============

  # Chunk array into groups with count
  # @param array [Array] Array to chunk
  # @param size [Integer] Chunk size
  # @return [Array<Array>] Chunked arrays
  def chunk_array(array, size)
    return [] if array.blank? || size <= 0

    array.each_slice(size).to_a
  end

  # Get elements that appear more than once
  # @param array [Array] Array to analyze
  # @return [Array] Duplicate elements
  def find_duplicates(array)
    return [] if array.blank?

    array.group_by(&:itself)
         .select { |_, v| v.size > 1 }
         .keys
  end
end
