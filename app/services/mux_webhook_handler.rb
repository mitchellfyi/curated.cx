# frozen_string_literal: true

# Handles Mux webhook events for live stream state changes.
#
# Supported events:
# - video.live_stream.active: Stream went live
# - video.live_stream.idle: Stream stopped broadcasting
# - video.asset.ready: Replay asset is ready
#
class MuxWebhookHandler
  class UnhandledEventError < StandardError; end

  attr_reader :event

  def initialize(event)
    @event = event.with_indifferent_access
  end

  # Process the webhook event
  # @return [Boolean] true if handled successfully
  def process
    case event[:type]
    when "video.live_stream.active"
      handle_live_stream_active(event[:data])
    when "video.live_stream.idle"
      handle_live_stream_idle(event[:data])
    when "video.asset.ready"
      handle_asset_ready(event[:data])
    else
      Rails.logger.info("Unhandled Mux event type: #{event[:type]}")
      true
    end
  end

  private

  # Handle stream going live
  def handle_live_stream_active(data)
    live_stream = find_live_stream(data[:id])
    return true unless live_stream

    ActiveRecord::Base.transaction do
      live_stream.update!(
        status: :live,
        started_at: Time.current
      )
    end

    # Queue notification job if site has notifications enabled
    if live_stream.site.streaming_notify_on_live?
      NotifyLiveStreamSubscribersJob.perform_later(live_stream.id)
    end

    Rails.logger.info("Live stream #{live_stream.id} is now active")
    true
  rescue StandardError => e
    Rails.logger.error("Error handling video.live_stream.active: #{e.message}")
    raise
  end

  # Handle stream going idle (stopped broadcasting)
  def handle_live_stream_idle(data)
    live_stream = find_live_stream(data[:id])
    return true unless live_stream

    # Only end if currently live
    return true unless live_stream.status_live?

    ActiveRecord::Base.transaction do
      live_stream.update!(
        status: :ended,
        ended_at: Time.current
      )

      # Mark all active viewers as left
      live_stream.viewers.active.find_each do |viewer|
        viewer.leave!
      end
    end

    Rails.logger.info("Live stream #{live_stream.id} ended (idle)")
    true
  rescue StandardError => e
    Rails.logger.error("Error handling video.live_stream.idle: #{e.message}")
    raise
  end

  # Handle replay asset being ready
  def handle_asset_ready(data)
    # The asset's passthrough contains the live stream info
    passthrough = parse_passthrough(data[:passthrough])
    return true unless passthrough

    # Find the live stream that created this asset
    live_stream = find_live_stream_by_asset(data)
    return true unless live_stream

    playback_id = data.dig(:playback_ids, 0, :id)

    live_stream.update!(
      mux_asset_id: data[:id],
      replay_playback_id: playback_id
    )

    Rails.logger.info("Replay ready for live stream #{live_stream.id}")
    true
  rescue StandardError => e
    Rails.logger.error("Error handling video.asset.ready: #{e.message}")
    raise
  end

  def find_live_stream(mux_stream_id)
    return nil unless mux_stream_id.present?

    LiveStream.without_site_scope.find_by(mux_stream_id: mux_stream_id)
  end

  def find_live_stream_by_asset(data)
    # Try to find via passthrough data first
    passthrough = parse_passthrough(data[:passthrough])
    if passthrough && passthrough[:site_id].present?
      site = Site.find_by(id: passthrough[:site_id])
      return nil unless site

      return LiveStream.for_site(site).find_by(title: passthrough[:title]) if passthrough[:title]
    end

    # Fallback: find by mux_stream_id from live_stream_id in asset data
    live_stream_id = data[:live_stream_id]
    find_live_stream(live_stream_id) if live_stream_id
  end

  def parse_passthrough(passthrough)
    return nil unless passthrough.present?

    JSON.parse(passthrough).with_indifferent_access
  rescue JSON::ParserError
    nil
  end
end
