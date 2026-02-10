# frozen_string_literal: true

# Job to capture a screenshot for an Entry.
# Uses ScreenshotService to capture and store the screenshot URL.
#
class CaptureScreenshotJob < ApplicationJob
  include JobLogging

  queue_as :screenshots

  retry_on ScreenshotService::ScreenshotError, wait: :polynomially_longer, attempts: 3
  discard_on ScreenshotService::ConfigurationError
  discard_on ActiveRecord::RecordNotFound

  def perform(entry_id)
    entry = Entry.find(entry_id)

    if entry.screenshot_url.present?
      log_job_info("Screenshot already exists", entry_id: entry_id)
      return
    end

    result = ScreenshotService.capture_for_entry(entry)

    if result
      log_job_info("Screenshot captured", entry_id: entry_id, screenshot_url: result[:screenshot_url])
    else
      log_job_warning("Screenshot capture failed, used fallback", entry_id: entry_id)
    end
  end
end
