# frozen_string_literal: true

# Periodic job to refresh stale screenshots.
# Enqueues CaptureScreenshotJob for feed entries whose screenshots
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
    stale_items = Entry.feed_items
      .where.not(screenshot_captured_at: nil)
      .where("screenshot_captured_at < ?", REFRESH_INTERVAL.ago)
      .limit(BATCH_SIZE)

    log_job_info("Refreshing stale screenshots", count: stale_items.count)

    stale_items.find_each do |entry|
      entry.update_columns(screenshot_url: nil, screenshot_captured_at: nil)
      CaptureScreenshotJob.perform_later(entry.id)
    end
  end
end
