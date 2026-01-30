# frozen_string_literal: true

# Job to confirm a boost click after the 24-hour waiting period.
#
# This job is enqueued when a click is recorded, with a 24-hour delay.
# It confirms the click to prevent gaming through immediate cancellation.
#
class ConfirmBoostClickJob < ApplicationJob
  queue_as :default

  def perform(click_id)
    click = BoostClick.find_by(id: click_id)
    return unless click # Record may have been deleted

    # Skip if not pending (already processed or cancelled)
    return unless click.pending?

    click.confirm!
    Rails.logger.info("BoostClick #{click.id} confirmed after 24h waiting period")
  rescue StandardError => e
    log_job_error(e, click_id: click_id)
    raise
  end
end
