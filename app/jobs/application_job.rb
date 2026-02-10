# frozen_string_literal: true

# Require error classes that are used in retry_on/discard_on declarations
# This ensures they're loaded before the class body is evaluated
require_dependency "application_error"

class ApplicationJob < ActiveJob::Base
  # Retry transient external service errors (API timeouts, network issues)
  retry_on ExternalServiceError, wait: :polynomially_longer, attempts: 3

  # Retry DNS errors (may be temporary network issues)
  retry_on DnsError, wait: :polynomially_longer, attempts: 3

  # Discard jobs that encounter permanent configuration errors
  discard_on ConfigurationError

  # Discard if the underlying record was deleted before job ran
  discard_on ActiveRecord::RecordNotFound

  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  protected

  # Log an error with structured context including tenant and request information.
  #
  # @param error [Exception] The error to log
  # @param context [Hash] Additional context to include in the log
  #
  # Example:
  #   log_job_error(error, listing_id: listing.id)
  #   # => "ScrapeMetadataJob failed: TimeoutError - Connection timed out
  #   #     {job_id: '...', tenant_id: 1, site_id: 2, listing_id: 123}"
  #
  def log_job_error(error, **context)
    full_context = build_error_context(context)

    Rails.logger.error(
      "#{self.class.name} failed: #{error.class} - #{error.message} #{full_context.to_json}"
    )
  end

  # Log an informational message with structured context.
  #
  # @param message [String] The info message
  # @param context [Hash] Additional context to include in the log
  #
  def log_job_info(message, **context)
    full_context = build_error_context(context)

    Rails.logger.info(
      "#{self.class.name}: #{message} #{full_context.to_json}"
    )
  end

  # Log a warning with structured context.
  #
  # @param message [String] The warning message
  # @param context [Hash] Additional context to include in the log
  #
  def log_job_warning(message, **context)
    full_context = build_error_context(context)

    Rails.logger.warn(
      "#{self.class.name}: #{message} #{full_context.to_json}"
    )
  end

  private

  def build_error_context(extra_context)
    {
      job_id: job_id,
      tenant_id: Current.tenant&.id,
      site_id: Current.site&.id,
      queue: queue_name
    }.compact.merge(extra_context)
  end
end
