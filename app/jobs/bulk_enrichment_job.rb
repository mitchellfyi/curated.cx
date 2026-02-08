# frozen_string_literal: true

# Job for batch processing enrichment on multiple content items.
# Useful for backfilling enrichment on existing content or
# re-processing items that failed enrichment.
#
# Accepts an array of content item IDs and enqueues EnrichContentItemJob
# for each one, with a small delay between batches to avoid overloading.
#
class BulkEnrichmentJob < ApplicationJob
  include JobLogging

  queue_as :low

  MAX_BATCH_SIZE = 500

  def perform(content_item_ids: nil, scope: "pending")
    items = resolve_items(content_item_ids, scope)
    count = 0

    items.find_each do |item|
      item.reset_enrichment!
      EnrichContentItemJob.perform_later(item.id)
      count += 1
      break if count >= MAX_BATCH_SIZE
    end

    log_job_info("Bulk enrichment queued", enqueued_count: count, scope: scope)
  end

  private

  def resolve_items(content_item_ids, scope)
    if content_item_ids.present?
      ContentItem.where(id: content_item_ids)
    else
      case scope
      when "pending"
        ContentItem.enrichment_pending
      when "failed"
        ContentItem.enrichment_failed
      when "all"
        ContentItem.where.not(enrichment_status: "enriching")
      else
        ContentItem.enrichment_pending
      end
    end
  end
end
