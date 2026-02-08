# frozen_string_literal: true

# Job to orchestrate the content enrichment pipeline for a ContentItem.
# Runs MetaInspector metadata extraction via LinkEnrichmentService,
# then chains to AiEditorialJob and CaptureScreenshotJob.
#
# Pipeline:
#   1. EnrichContentItemJob (metadata extraction)
#   2. AiEditorialJob (AI summary, quality scoring)
#   3. CaptureScreenshotJob (optional screenshot capture)
#
# Error Handling:
#   - Retries on EnrichmentError (network/API issues)
#   - Discards on record not found
#   - Records errors in enrichment_errors and marks status as failed
#
class EnrichContentItemJob < ApplicationJob
  include JobLogging

  queue_as :enrichment

  retry_on LinkEnrichmentService::EnrichmentError, wait: :polynomially_longer, attempts: 3

  def perform(content_item_id)
    content_item = ContentItem.find(content_item_id)

    # Set tenant context
    Current.tenant = content_item.site.tenant
    Current.site = content_item.site

    content_item.mark_enrichment_started!

    # Step 1: Metadata enrichment
    enrich_metadata(content_item)

    # Step 2: Chain to AI editorial job
    if content_item.source&.editorialisation_enabled?
      AiEditorialJob.perform_later(content_item_id)
    else
      # No AI step needed - chain directly to screenshot
      CaptureScreenshotJob.perform_later(content_item_id)
      content_item.mark_enrichment_complete!
    end

    log_job_info("Enrichment metadata complete", content_item_id: content_item_id)
  rescue LinkEnrichmentService::EnrichmentError => e
    content_item&.mark_enrichment_failed!(e.message)
    raise
  rescue StandardError => e
    content_item&.mark_enrichment_failed!(e.message) if content_item&.persisted?
    raise
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def enrich_metadata(content_item)
    metadata = LinkEnrichmentService.enrich(content_item.url_canonical)

    attrs = {}
    attrs[:og_image_url] = metadata[:og_image_url] if metadata[:og_image_url].present?
    attrs[:author_name] = metadata[:author_name] if metadata[:author_name].present?
    attrs[:word_count] = metadata[:word_count] if metadata[:word_count].present? && metadata[:word_count] > 0
    attrs[:read_time_minutes] = metadata[:read_time_minutes] if metadata[:read_time_minutes].present?
    attrs[:favicon_url] = metadata[:favicon_url] if metadata[:favicon_url].present?

    # Update title/description only if not already set
    attrs[:title] = metadata[:title] if content_item.title.blank? && metadata[:title].present?
    attrs[:description] = metadata[:description] if content_item.description.blank? && metadata[:description].present?

    content_item.update_columns(attrs) if attrs.present?
  end
end
