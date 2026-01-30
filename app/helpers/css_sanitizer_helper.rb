# frozen_string_literal: true

# Helper for sanitizing CSS to prevent XSS attacks.
# Strips dangerous patterns while preserving valid CSS properties.
module CssSanitizerHelper
  # Patterns that should be removed from CSS as they can execute scripts
  DANGEROUS_PATTERNS = [
    /javascript:/i,
    /expression\s*\(/i,
    /url\s*\(\s*["']?\s*javascript:/i,
    /@import/i,
    /behavior\s*:/i,
    /-moz-binding/i,
    /binding\s*:/i,
    /<\s*script/i,
    /<\s*\/\s*script/i,
    /on\w+\s*=/i
  ].freeze

  # Sanitize CSS string by removing dangerous patterns.
  # @param css [String] The CSS to sanitize
  # @return [ActiveSupport::SafeBuffer] Sanitized CSS safe for output
  def sanitize_css(css)
    return "".html_safe if css.blank?

    sanitized = css.dup

    # Remove dangerous patterns
    DANGEROUS_PATTERNS.each do |pattern|
      sanitized = sanitized.gsub(pattern, "/* removed */")
    end

    # Remove any remaining script-like content
    sanitized = sanitized.gsub(/[<>]/, "")

    sanitized.html_safe
  end
end
