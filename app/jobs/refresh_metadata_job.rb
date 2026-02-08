# frozen_string_literal: true

# Job to refresh metadata for stale content items.
# Finds items whose enrichment data is older than the configured interval
# and re-enqueues them through the enrichment pipeline.
#
# Intended to run periodically (e.g., daily via cron/scheduler).
#
class RefreshMetadataJob < ApplicationJob
  include JobLogging

  queue_as :low

  BATCH_SIZE = 50
  DEFAULT_STALE_INTERVAL = 30.days

  def perform(stale_interval: DEFAULT_STALE_INTERVAL, batch_size: BATCH_SIZE)
    stale_items = ContentItem.enrichment_stale(stale_interval).limit(batch_size)
    count = 0

    stale_items.find_each do |item|
      item.reset_enrichment!
      EnrichContentItemJob.perform_later(item.id)
      count += 1
    end

    log_job_info("Refresh metadata complete", refreshed_count: count, stale_interval: stale_interval.inspect)
  end
end
