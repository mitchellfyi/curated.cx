# frozen_string_literal: true

# Job to run AI editorial processing as part of the enrichment pipeline.
# Generates AI summary, key takeaways, and quality scoring.
#
# This job wraps EditorialisationService and chains to CaptureScreenshotJob
# upon completion. Updates the enrichment_status on the content item.
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

  def perform(content_item_id)
    @content_item = ContentItem.find(content_item_id)
    @site = @content_item.site
    @tenant = @site.tenant

    Current.tenant = @tenant
    Current.site = @site

    # Check if workflow is paused
    return if workflow_paused?(source: @content_item.source, tenant: @tenant)

    # Check AI usage limits
    unless AiUsageTracker.can_make_request?
      log_job_warning("AI usage limit reached - skipping", content_item_id: content_item_id)
      chain_to_screenshot(content_item_id)
      @content_item.mark_enrichment_complete!
      return
    end

    result = EditorialisationService.editorialise(@content_item)

    track_ai_usage(result) if result.completed?
    log_result(result)

    # Chain to screenshot capture
    chain_to_screenshot(content_item_id)

    # Mark enrichment complete
    @content_item.mark_enrichment_complete!
  rescue AiApiError, AiTimeoutError, AiRateLimitError => e
    @content_item&.mark_enrichment_failed!(e.message)
    raise
  rescue AiInvalidResponseError, AiConfigurationError => e
    @content_item&.mark_enrichment_failed!(e.message)
    raise
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def chain_to_screenshot(content_item_id)
    CaptureScreenshotJob.perform_later(content_item_id)
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

  def log_result(editorialisation)
    case editorialisation.status
    when "completed"
      log_job_info(
        "AI editorial complete",
        content_item_id: @content_item.id,
        tokens: editorialisation.tokens_used,
        duration_ms: editorialisation.duration_ms
      )
    when "skipped"
      log_job_info(
        "AI editorial skipped",
        content_item_id: @content_item.id,
        reason: editorialisation.error_message
      )
    when "failed"
      log_job_warning(
        "AI editorial failed",
        content_item_id: @content_item.id,
        error: editorialisation.error_message
      )
    end
  end
end
