# frozen_string_literal: true

# Job for batch processing enrichment on multiple feed entries.
# Accepts an array of entry IDs (feed) and enqueues EnrichEntryJob for each.
#
class BulkEnrichmentJob < ApplicationJob
  include JobLogging

  queue_as :low

  MAX_BATCH_SIZE = 500

  def perform(entry_ids: nil, scope: "pending")
    items = resolve_items(entry_ids, scope)
    count = 0

    items.find_each do |entry|
      entry.reset_enrichment!
      EnrichEntryJob.perform_later(entry.id)
      count += 1
      break if count >= MAX_BATCH_SIZE
    end

    log_job_info("Bulk enrichment queued", enqueued_count: count, scope: scope)
  end

  private

  def resolve_items(entry_ids, scope)
    base = Entry.feed_items
    if entry_ids.present?
      base.where(id: entry_ids)
    else
      case scope
      when "pending"
        base.enrichment_pending
      when "failed"
        base.enrichment_failed
      when "all"
        base.where.not(enrichment_status: "enriching")
      else
        base.enrichment_pending
      end
    end
  end
end
