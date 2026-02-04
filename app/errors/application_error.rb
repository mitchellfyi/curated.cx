# frozen_string_literal: true

# Base error class hierarchy for the application.
#
# All application-specific errors should inherit from ApplicationError
# to enable consistent error handling and logging.
#
# Error Categories:
#   - ExternalServiceError: Transient failures from external APIs/networks (retryable)
#   - ContentExtractionError: Parsing/scraping failures (may or may not be retryable)
#   - ConfigurationError: Missing config or invalid setup (permanent, discard job)
#   - DnsError: DNS resolution failures (may be retryable)
#
# Usage in Jobs:
#   retry_on ExternalServiceError, wait: :polynomially_longer, attempts: 3
#   discard_on ConfigurationError
#
class ApplicationError < StandardError
  # Optional context hash for structured logging
  attr_reader :context

  def initialize(message = nil, context: {})
    @context = context
    super(message)
  end

  def to_h
    {
      error_class: self.class.name,
      message: message,
      context: context
    }
  end
end

# Transient failures from external services (APIs, HTTP requests, etc.)
# These are typically retryable after a delay.
class ExternalServiceError < ApplicationError; end

# Failures during content extraction (parsing HTML, extracting metadata, etc.)
# May be retryable if the issue is temporary, but often indicates bad content.
class ContentExtractionError < ApplicationError; end

# Configuration or setup errors that indicate permanent problems.
# Jobs should discard work that encounters these errors.
class ConfigurationError < ApplicationError; end

# DNS resolution failures.
# May be retryable for temporary network issues.
class DnsError < ApplicationError; end
