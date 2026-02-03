# frozen_string_literal: true

# Shared logging utilities for background jobs
module JobLogging
  extend ActiveSupport::Concern

  private

  def log_job_info(message, **context)
    Rails.logger.info(format_log_message(message, context))
  end

  def log_job_warning(message, **context)
    Rails.logger.warn(format_log_message(message, context))
  end

  def log_job_error(error, **context)
    Rails.logger.error(format_log_message(
      "#{error.class}: #{error.message}",
      context.merge(backtrace: error.backtrace&.first(5))
    ))
  end

  def format_log_message(message, context)
    job_context = {
      job: self.class.name,
      job_id: job_id
    }

    "[#{job_context[:job]}] #{message} | #{job_context.merge(context).to_json}"
  end

  # Wrap job execution with timing and logging
  def with_job_logging(description = "Job execution")
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    log_job_info("Starting: #{description}")

    result = yield

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    log_job_info("Completed: #{description}", duration_ms: duration_ms)

    result
  rescue StandardError => e
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    log_job_error(e, duration_ms: duration_ms, description: description)
    raise
  end
end
