# frozen_string_literal: true

# Job to publish content items and listings that are scheduled for now or earlier.
# Runs periodically (typically every minute) via cron/scheduler.
#
# Processes:
# - ContentItems with scheduled_for <= now and published_at nil
# - Listings with scheduled_for <= now and published_at nil
#
class PublishScheduledContentJob < ApplicationJob
  include JobLogging

  queue_as :default

  BATCH_SIZE = 100

  def perform
    with_job_logging("Publish scheduled content") do
      @stats = { content_items: 0, listings: 0, failed: 0 }

      publish_content_items
      publish_listings

      log_job_info("Publishing completed", **@stats) if @stats.values.sum > 0
    end
  end

  private

  def publish_content_items
    ContentItem.due_for_publishing.find_each(batch_size: BATCH_SIZE) do |item|
      publish_item(item, :content_items)
    end
  end

  def publish_listings
    Listing.due_for_publishing.find_each(batch_size: BATCH_SIZE) do |item|
      publish_item(item, :listings)
    end
  end

  def publish_item(item, stat_key)
    unless item.site&.tenant
      log_job_warning("Skipping item with missing site or tenant", type: item.class.name, id: item.id)
      @stats[:failed] += 1
      return
    end

    ActsAsTenant.with_tenant(item.site.tenant) do
      item.update!(published_at: Time.current, scheduled_for: nil)
      @stats[stat_key] += 1

      log_job_info("Published scheduled content",
                   type: item.class.name,
                   id: item.id,
                   title: item.title.truncate(50))
    end
  rescue StandardError => e
    @stats[:failed] += 1
    log_job_warning("Failed to publish scheduled content",
                    type: item.class.name,
                    id: item.id,
                    error: e.message)
  end
end
