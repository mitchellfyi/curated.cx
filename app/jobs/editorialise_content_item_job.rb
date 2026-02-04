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

    result = EditorialisationService.editorialise(@content_item)

    log_result(result)
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

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
