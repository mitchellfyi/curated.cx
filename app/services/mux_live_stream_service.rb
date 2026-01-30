# frozen_string_literal: true

# Service for managing Mux Live Streams.
#
# Usage:
#   service = MuxLiveStreamService.new(site)
#   result = service.create_stream("My Stream Title")
#   # => { mux_stream_id: "...", mux_playback_id: "...", stream_key: "..." }
#
class MuxLiveStreamService
  class MuxNotConfiguredError < StandardError; end
  class MuxApiError < StandardError; end

  attr_reader :site

  def initialize(site)
    @site = site
    validate_configuration!
  end

  # Creates a new live stream in Mux.
  # @param title [String] The stream title for identification
  # @return [Hash] { mux_stream_id:, mux_playback_id:, stream_key: }
  def create_stream(title)
    response = live_streams_api.create_live_stream(
      MuxRuby::CreateLiveStreamRequest.new(
        playback_policy: [ MuxRuby::PlaybackPolicy::PUBLIC ],
        new_asset_settings: {
          playback_policy: [ MuxRuby::PlaybackPolicy::PUBLIC ]
        },
        passthrough: build_passthrough(title)
      )
    )

    stream = response.data
    {
      mux_stream_id: stream.id,
      mux_playback_id: stream.playback_ids&.first&.id,
      stream_key: stream.stream_key
    }
  rescue MuxRuby::ApiError => e
    Rails.logger.error("Mux API error creating stream: #{e.message}")
    raise MuxApiError, "Failed to create Mux stream: #{e.message}"
  end

  # Gets the playback URL for a stream or asset.
  # @param playback_id [String] The Mux playback ID
  # @return [String] The HLS playback URL
  def playback_url(playback_id)
    return nil unless playback_id.present?

    "https://stream.mux.com/#{playback_id}.m3u8"
  end

  # Disables a live stream (prevents new connections).
  # @param mux_stream_id [String] The Mux stream ID
  def disable_stream(mux_stream_id)
    live_streams_api.disable_live_stream(mux_stream_id)
    true
  rescue MuxRuby::ApiError => e
    Rails.logger.error("Mux API error disabling stream: #{e.message}")
    raise MuxApiError, "Failed to disable Mux stream: #{e.message}"
  end

  # Enables a live stream (allows connections).
  # @param mux_stream_id [String] The Mux stream ID
  def enable_stream(mux_stream_id)
    live_streams_api.enable_live_stream(mux_stream_id)
    true
  rescue MuxRuby::ApiError => e
    Rails.logger.error("Mux API error enabling stream: #{e.message}")
    raise MuxApiError, "Failed to enable Mux stream: #{e.message}"
  end

  # Deletes a live stream from Mux.
  # @param mux_stream_id [String] The Mux stream ID
  def delete_stream(mux_stream_id)
    live_streams_api.delete_live_stream(mux_stream_id)
    true
  rescue MuxRuby::ApiError => e
    Rails.logger.error("Mux API error deleting stream: #{e.message}")
    raise MuxApiError, "Failed to delete Mux stream: #{e.message}"
  end

  # Gets asset information (for replay).
  # @param asset_id [String] The Mux asset ID
  # @return [Hash] { playback_id:, status:, duration: }
  def get_asset(asset_id)
    response = assets_api.get_asset(asset_id)
    asset = response.data

    {
      playback_id: asset.playback_ids&.first&.id,
      status: asset.status,
      duration: asset.duration
    }
  rescue MuxRuby::ApiError => e
    Rails.logger.error("Mux API error getting asset: #{e.message}")
    raise MuxApiError, "Failed to get Mux asset: #{e.message}"
  end

  # Gets live stream information.
  # @param mux_stream_id [String] The Mux stream ID
  # @return [Hash] { status:, active_asset_id:, playback_id: }
  def get_stream(mux_stream_id)
    response = live_streams_api.get_live_stream(mux_stream_id)
    stream = response.data

    {
      status: stream.status,
      active_asset_id: stream.active_asset_id,
      playback_id: stream.playback_ids&.first&.id
    }
  rescue MuxRuby::ApiError => e
    Rails.logger.error("Mux API error getting stream: #{e.message}")
    raise MuxApiError, "Failed to get Mux stream: #{e.message}"
  end

  private

  def validate_configuration!
    config = Rails.application.config.mux
    if config[:token_id].blank? || config[:token_secret].blank?
      raise MuxNotConfiguredError, "Mux API credentials not configured"
    end
  end

  def live_streams_api
    @live_streams_api ||= MuxRuby::LiveStreamsApi.new
  end

  def assets_api
    @assets_api ||= MuxRuby::AssetsApi.new
  end

  def build_passthrough(title)
    {
      site_id: site.id,
      title: title
    }.to_json
  end
end
