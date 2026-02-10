# frozen_string_literal: true

# Job to orchestrate the content enrichment pipeline for a feed Entry.
# Runs MetaInspector metadata extraction via LinkEnrichmentService,
# then chains to AiEditorialJob and CaptureScreenshotJob.
#
# Pipeline:
#   1. EnrichEntryJob (metadata extraction)
#   2. AiEditorialJob (AI summary, quality scoring)
#   3. CaptureScreenshotJob (optional screenshot capture)
#
class EnrichEntryJob < ApplicationJob
  include JobLogging

  queue_as :enrichment

  retry_on LinkEnrichmentService::EnrichmentError, wait: :polynomially_longer, attempts: 3

  def perform(entry_id)
    entry = Entry.find(entry_id)

    Current.tenant = entry.site&.tenant
    Current.site = entry.site

    entry.mark_enrichment_started!

    enrich_metadata(entry)

    if entry.source&.editorialisation_enabled?
      AiEditorialJob.perform_later(entry_id)
    else
      CaptureScreenshotJob.perform_later(entry_id)
      entry.mark_enrichment_complete!
    end

    log_job_info("Enrichment metadata complete", entry_id: entry_id)
  rescue LinkEnrichmentService::EnrichmentError => e
    entry&.mark_enrichment_failed!(e.message)
    raise
  rescue StandardError => e
    entry&.mark_enrichment_failed!(e.message) if entry&.persisted?
    raise
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def enrich_metadata(entry)
    metadata = LinkEnrichmentService.enrich(entry.url_canonical)

    attrs = {}
    attrs[:og_image_url] = metadata[:og_image_url] if metadata[:og_image_url].present?
    attrs[:author_name] = metadata[:author_name] if metadata[:author_name].present?
    attrs[:word_count] = metadata[:word_count] if metadata[:word_count].present? && metadata[:word_count] > 0
    attrs[:read_time_minutes] = metadata[:read_time_minutes] if metadata[:read_time_minutes].present?
    attrs[:favicon_url] = metadata[:favicon_url] if metadata[:favicon_url].present?
    attrs[:title] = metadata[:title] if entry.title.blank? && metadata[:title].present?
    attrs[:description] = metadata[:description] if entry.description.blank? && metadata[:description].present?

    entry.update_columns(attrs) if attrs.present?
  end
end
