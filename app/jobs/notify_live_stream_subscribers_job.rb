# frozen_string_literal: true

class NotifyLiveStreamSubscribersJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform(live_stream_id)
    live_stream = LiveStream.without_site_scope.find_by(id: live_stream_id)
    return unless live_stream
    return unless live_stream.status_live?

    site = live_stream.site
    return unless site.streaming_notify_on_live?

    ActsAsTenant.with_tenant(site.tenant) do
      DigestSubscription.where(site: site).active.find_each(batch_size: BATCH_SIZE) do |subscription|
        send_notification(subscription, live_stream)
      end
    end
  end

  private

  def send_notification(subscription, live_stream)
    LiveStreamMailer.stream_live_notification(subscription, live_stream).deliver_later
  rescue StandardError => e
    Rails.logger.error(
      "Failed to send live stream notification to #{subscription.user.email}: #{e.message}"
    )
    # Don't fail the whole job for one subscriber
  end
end
