# frozen_string_literal: true

# Job to publish feed and directory entries that are scheduled for now or earlier.
#
class PublishScheduledContentJob < ApplicationJob
  include JobLogging

  queue_as :default

  BATCH_SIZE = 100

  def perform
    with_job_logging("Publish scheduled content") do
      @stats = { feed: 0, directory: 0, failed: 0 }

      Entry.feed_items.due_for_publishing.find_each(batch_size: BATCH_SIZE) { |item| publish_item(item, :feed) }
      Entry.directory_items.due_for_publishing.find_each(batch_size: BATCH_SIZE) { |item| publish_item(item, :directory) }

      log_job_info("Publishing completed", **@stats) if @stats.values.sum > 0
    end
  end

  private

  def publish_item(item, stat_key)
    unless item.site&.tenant
      log_job_warning("Skipping entry with missing site or tenant", entry_id: item.id)
      @stats[:failed] += 1
      return
    end

    ActsAsTenant.with_tenant(item.site.tenant) do
      item.update!(published_at: Time.current, scheduled_for: nil)
      @stats[stat_key] += 1

      log_job_info("Published scheduled content",
                   entry_id: item.id,
                   title: item.title.to_s.truncate(50))
    end
  rescue StandardError => e
    @stats[:failed] += 1
    log_job_warning("Failed to publish scheduled content", entry_id: item.id, error: e.message)
  end
end
