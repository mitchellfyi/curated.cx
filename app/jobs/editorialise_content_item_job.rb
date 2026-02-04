# frozen_string_literal: true

# Job to run AI editorialisation on a ContentItem.
# Uses the EditorialisationService for actual processing.
#
# This job runs asynchronously on the :editorialisation queue to avoid
# blocking the main ingestion pipeline. It is triggered via ContentItem
# after_create callback when the source has editorialisation enabled.
#
# Error Handling:
#   - Retries on AiApiError, AiRateLimitError, AiTimeoutError
#   - Discards on AiInvalidResponseError, AiConfigurationError
#   - Discards on record not found
#
class EditorialiseContentItemJob < ApplicationJob
  include JobLogging
  include WorkflowPausable

  self.workflow_type = :editorialisation

  queue_as :editorialisation

  # Override default retry for AI-specific errors
  retry_on AiApiError, wait: :polynomially_longer, attempts: 3
  retry_on AiTimeoutError, wait: :polynomially_longer, attempts: 3
  retry_on AiRateLimitError, wait: 60.seconds, attempts: 5

  # Non-retryable AI errors
  discard_on AiInvalidResponseError
  discard_on AiConfigurationError

  def perform(content_item_id)
    @content_item = ContentItem.find(content_item_id)
    @site = @content_item.site
    @tenant = @site.tenant

    # Set tenant context for the job
    Current.tenant = @tenant
    Current.site = @site

    # Check if workflow is paused
    return if workflow_paused?(source: @content_item.source, tenant: @tenant)

    # Check AI usage limits
    unless AiUsageTracker.can_make_request?
      log_job_warning("AI usage limit reached - skipping", content_item_id: content_item_id)
      return
    end

    result = EditorialisationService.editorialise(@content_item)

    # Track AI usage after successful editorialisation
    track_ai_usage(result) if result.completed?

    log_result(result)
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def track_ai_usage(editorialisation)
    # Get token counts from the editorialisation
    input_tokens = editorialisation.input_tokens || (editorialisation.tokens_used.to_i * 0.7).round
    output_tokens = editorialisation.output_tokens || (editorialisation.tokens_used.to_i * 0.3).round

    AiUsageTracker.track!(
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      editorialisation: editorialisation
    )
  rescue StandardError => e
    # Don't fail the job if tracking fails
    Rails.logger.error("Failed to track AI usage: #{e.message}")
  end

  def log_result(editorialisation)
    case editorialisation.status
    when "completed"
      Rails.logger.info(
        "#{self.class.name}: Successfully editorialised content_item_id=#{@content_item.id} " \
        "tokens=#{editorialisation.tokens_used} duration_ms=#{editorialisation.duration_ms}"
      )
    when "skipped"
      Rails.logger.info(
        "#{self.class.name}: Skipped content_item_id=#{@content_item.id} " \
        "reason=#{editorialisation.error_message}"
      )
    when "failed"
      log_job_warning(
        "Editorialisation failed",
        content_item_id: @content_item.id,
        error: editorialisation.error_message
      )
    end
  end
end
