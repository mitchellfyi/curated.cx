# frozen_string_literal: true

# Helper for sanitizing CSS to prevent XSS attacks.
# Strips dangerous patterns while preserving valid CSS properties.
#
# Security notes:
# - Removes JavaScript URLs and expressions that can execute code
# - Blocks IE-specific behaviors and Mozilla bindings
# - Strips @import to prevent loading external stylesheets
# - Removes HTML tags that might be injected
# - Blocks event handler patterns
#
module CssSanitizerHelper
  # Patterns that should be removed from CSS as they can execute scripts
  DANGEROUS_PATTERNS = [
    # JavaScript execution
    /javascript\s*:/i,
    /vbscript\s*:/i,
    /data\s*:/i,                              # data: URLs can embed scripts
    /expression\s*\(/i,                       # IE expression() function
    /url\s*\(\s*["']?\s*javascript:/i,
    /url\s*\(\s*["']?\s*data:/i,

    # External resources that could be malicious
    /@import/i,
    /@charset/i,                              # Can affect parsing

    # IE-specific behaviors
    /behavior\s*:/i,
    /-ms-behavior\s*:/i,

    # Mozilla-specific
    /-moz-binding/i,
    /binding\s*:/i,

    # HTML injection attempts
    /<\s*script/i,
    /<\s*\/\s*script/i,
    /<\s*style/i,
    /<\s*\/\s*style/i,
    /<\s*link/i,
    /<\s*iframe/i,
    /<\s*object/i,
    /<\s*embed/i,

    # Event handlers
    /on\w+\s*=/i,

    # Unicode escapes that could bypass filters
    /\\u/i,                                   # Unicode escapes
    /\\x/i                                    # Hex escapes
  ].freeze

  # Maximum CSS length to prevent DoS via large inputs
  MAX_CSS_LENGTH = 50_000

  # Sanitize CSS string by removing dangerous patterns.
  # @param css [String] The CSS to sanitize
  # @return [ActiveSupport::SafeBuffer] Sanitized CSS safe for output
  def sanitize_css(css)
    return "".html_safe if css.blank?

    # Truncate excessively long CSS
    sanitized = css.to_s.truncate(MAX_CSS_LENGTH)

    # Remove null bytes
    sanitized = sanitized.gsub("\x00", "")

    # Remove dangerous patterns
    DANGEROUS_PATTERNS.each do |pattern|
      sanitized = sanitized.gsub(pattern, "/* sanitized */")
    end

    # Remove HTML tag characters
    sanitized = sanitized.gsub(/[<>]/, "")

    # Remove any control characters except newlines and tabs
    sanitized = sanitized.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")

    sanitized.html_safe
  end

  # Check if CSS contains potentially dangerous patterns (for logging/alerting)
  # @param css [String] The CSS to check
  # @return [Boolean] true if dangerous patterns found
  def css_contains_dangerous_patterns?(css)
    return false if css.blank?

    DANGEROUS_PATTERNS.any? { |pattern| css.match?(pattern) }
  end
end
