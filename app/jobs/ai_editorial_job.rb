# frozen_string_literal: true

# Job to run AI editorial processing as part of the enrichment pipeline.
# Generates AI summary, key takeaways, and quality scoring.
#
# This job wraps EditorialisationService and chains to CaptureScreenshotJob
# upon completion. Updates the enrichment_status on the entry.
#
# Error Handling:
#   - Retries on AiApiError, AiTimeoutError, AiRateLimitError
#   - Discards on AiInvalidResponseError, AiConfigurationError
#   - Records errors in enrichment_errors on failure
#
class AiEditorialJob < ApplicationJob
  include JobLogging
  include WorkflowPausable

  self.workflow_type = :editorialisation

  queue_as :editorialisation

  retry_on AiApiError, wait: :polynomially_longer, attempts: 3
  retry_on AiTimeoutError, wait: :polynomially_longer, attempts: 3
  retry_on AiRateLimitError, wait: 60.seconds, attempts: 5

  discard_on AiInvalidResponseError
  discard_on AiConfigurationError

  def perform(entry_id)
    @entry = Entry.find(entry_id)
    @site = @entry.site
    @tenant = @site&.tenant

    Current.tenant = @tenant
    Current.site = @site

    return if workflow_paused?(source: @entry.source, tenant: @tenant)

    unless AiUsageTracker.can_make_request?
      log_job_warning("AI usage limit reached - skipping", entry_id: entry_id)
      chain_to_screenshot(entry_id)
      @entry.mark_enrichment_complete!
      return
    end

    result = EditorialisationService.editorialise(@entry)

    track_ai_usage(result) if result.completed?
    log_result(result)

    chain_to_screenshot(entry_id)
    @entry.mark_enrichment_complete!
  rescue AiApiError, AiTimeoutError, AiRateLimitError => e
    @entry&.mark_enrichment_failed!(e.message)
    raise
  rescue AiInvalidResponseError, AiConfigurationError => e
    @entry&.mark_enrichment_failed!(e.message)
    raise
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def chain_to_screenshot(entry_id)
    CaptureScreenshotJob.perform_later(entry_id)
  end

  def track_ai_usage(editorialisation)
    input_tokens = editorialisation.input_tokens || (editorialisation.tokens_used.to_i * 0.7).round
    output_tokens = editorialisation.output_tokens || (editorialisation.tokens_used.to_i * 0.3).round

    AiUsageTracker.track!(
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      editorialisation: editorialisation
    )
  rescue StandardError => e
    Rails.logger.error("Failed to track AI usage: #{e.message}")
  end

  def log_result(result)
    case result.status
    when "completed"
      log_job_info(
        "AI editorial complete",
        entry_id: @entry.id,
        tokens: result.tokens_used,
        duration_ms: result.duration_ms
      )
    when "skipped"
      log_job_info(
        "AI editorial skipped",
        entry_id: @entry.id,
        reason: result.error_message
      )
    when "failed"
      log_job_warning(
        "AI editorial failed",
        entry_id: @entry.id,
        error: result.error_message
      )
    end
  end
end
