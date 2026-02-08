# frozen_string_literal: true

# Job to capture a screenshot for a ContentItem.
# Uses ScreenshotService to capture and store the screenshot URL.
#
# Enqueued when new content is ingested and needs a visual preview.
# Falls back to OG image if screenshot capture fails.
#
# Error Handling:
#   - Retries on ScreenshotError (network/API issues)
#   - Discards on ConfigurationError (missing API key)
#   - Discards on record not found
#
class CaptureScreenshotJob < ApplicationJob
  include JobLogging

  queue_as :screenshots

  retry_on ScreenshotService::ScreenshotError, wait: :polynomially_longer, attempts: 3
  discard_on ScreenshotService::ConfigurationError
  discard_on ActiveRecord::RecordNotFound

  def perform(content_item_id)
    content_item = ContentItem.find(content_item_id)

    if content_item.screenshot_url.present?
      log_job_info("Screenshot already exists", content_item_id: content_item_id)
      return
    end

    result = ScreenshotService.capture_for_content_item(content_item)

    if result
      log_job_info("Screenshot captured", content_item_id: content_item_id, screenshot_url: result[:screenshot_url])
    else
      log_job_warning("Screenshot capture failed, used fallback", content_item_id: content_item_id)
    end
  end
end
