# frozen_string_literal: true

# AI API error classes for editorialisation service.
#
# Error Hierarchy:
#   - AiApiError: Base for transient AI API failures (retryable)
#     - AiRateLimitError: Rate limit exceeded (retryable with longer wait)
#     - AiTimeoutError: API call timed out (retryable)
#   - AiInvalidResponseError: Malformed or unparseable response (non-retryable)
#   - AiConfigurationError: Missing API key or bad config (non-retryable)
#
# Usage in Jobs:
#   retry_on AiApiError, wait: :exponentially_longer, attempts: 3
#   retry_on AiRateLimitError, wait: 60.seconds, attempts: 5
#   discard_on AiInvalidResponseError
#   discard_on AiConfigurationError

# Transient AI API failures (network errors, server errors, etc.)
# These are typically safe to retry after a delay.
class AiApiError < ExternalServiceError; end

# Rate limit exceeded - should wait longer between retries.
class AiRateLimitError < AiApiError; end

# API call timed out - safe to retry.
class AiTimeoutError < AiApiError; end

# Response couldn't be parsed or was invalid format.
# Non-retryable - likely a prompt or API issue that won't fix itself.
class AiInvalidResponseError < ApplicationError; end

# Configuration error (missing API key, invalid model, etc.)
# Non-retryable - requires human intervention.
class AiConfigurationError < ConfigurationError; end
