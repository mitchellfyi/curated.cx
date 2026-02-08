# frozen_string_literal: true

# Periodic job to refresh stale screenshots.
# Enqueues CaptureScreenshotJob for content items whose screenshots
# are older than the configured refresh interval (default: 7 days).
#
# Intended to be run on a schedule (e.g., daily via cron/recurring job).
#
class RefreshScreenshotsJob < ApplicationJob
  include JobLogging

  queue_as :screenshots

  REFRESH_INTERVAL = 7.days
  BATCH_SIZE = 50

  def perform
    stale_items = ContentItem
      .where.not(screenshot_captured_at: nil)
      .where("screenshot_captured_at < ?", REFRESH_INTERVAL.ago)
      .limit(BATCH_SIZE)

    log_job_info("Refreshing stale screenshots", count: stale_items.count)

    stale_items.find_each do |content_item|
      # Clear existing screenshot so CaptureScreenshotJob will re-capture
      content_item.update_columns(screenshot_url: nil, screenshot_captured_at: nil)
      CaptureScreenshotJob.perform_later(content_item.id)
    end
  end
end
