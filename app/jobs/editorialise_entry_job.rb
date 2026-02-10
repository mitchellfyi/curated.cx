# frozen_string_literal: true

# Job to run AI editorialisation on a feed Entry.
# Uses EditorialisationService. Triggered after enrichment or from admin.
#
class EditorialiseEntryJob < ApplicationJob
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
      return
    end

    result = EditorialisationService.editorialise(@entry)

    track_ai_usage(result) if result.completed?

    log_result(result)
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

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
      Rails.logger.info(
        "#{self.class.name}: Successfully editorialised entry_id=#{@entry.id} " \
        "tokens=#{editorialisation.tokens_used} duration_ms=#{editorialisation.duration_ms}"
      )
    when "skipped"
      Rails.logger.info(
        "#{self.class.name}: Skipped entry_id=#{@entry.id} reason=#{editorialisation.error_message}"
      )
    when "failed"
      log_job_warning(
        "Editorialisation failed",
        entry_id: @entry.id,
        error: editorialisation.error_message
      )
    end
  end
end
