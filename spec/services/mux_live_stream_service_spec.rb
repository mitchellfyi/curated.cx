# frozen_string_literal: true

require "rails_helper"

RSpec.describe MuxLiveStreamService do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    Current.site = site
    # Ensure Mux is configured for tests
    allow(Rails.application.config).to receive(:mux).and_return({
      token_id: "test_token_id",
      token_secret: "test_token_secret",
      webhook_secret: "test_webhook_secret"
    })
  end

  describe "#initialize" do
    it "accepts a site" do
      expect {
        described_class.new(site)
      }.not_to raise_error
    end

    context "when Mux is not configured" do
      before do
        allow(Rails.application.config).to receive(:mux).and_return({
          token_id: nil,
          token_secret: nil
        })
      end

      it "raises MuxNotConfiguredError" do
        expect {
          described_class.new(site)
        }.to raise_error(MuxLiveStreamService::MuxNotConfiguredError)
      end
    end
  end

  describe "#create_stream" do
    let(:service) { described_class.new(site) }
    let(:mock_stream) do
      double("MuxRuby::LiveStream",
        id: "stream-123",
        stream_key: "secret-stream-key",
        playback_ids: [ double(id: "playback-456") ])
    end
    let(:mock_response) { double("MuxRuby::LiveStreamResponse", data: mock_stream) }
    let(:mock_live_streams_api) { instance_double(MuxRuby::LiveStreamsApi) }

    before do
      allow(MuxRuby::LiveStreamsApi).to receive(:new).and_return(mock_live_streams_api)
      allow(mock_live_streams_api).to receive(:create_live_stream).and_return(mock_response)
    end

    it "creates a live stream in Mux" do
      expect(mock_live_streams_api).to receive(:create_live_stream)
        .with(instance_of(MuxRuby::CreateLiveStreamRequest))

      service.create_stream("Test Stream")
    end

    it "returns stream details" do
      result = service.create_stream("Test Stream")

      expect(result[:mux_stream_id]).to eq("stream-123")
      expect(result[:mux_playback_id]).to eq("playback-456")
      expect(result[:stream_key]).to eq("secret-stream-key")
    end

    context "when Mux API fails" do
      before do
        allow(mock_live_streams_api).to receive(:create_live_stream)
          .and_raise(MuxRuby::ApiError.new(message: "API error"))
      end

      it "raises MuxApiError" do
        expect {
          service.create_stream("Test Stream")
        }.to raise_error(MuxLiveStreamService::MuxApiError, /Failed to create Mux stream/)
      end
    end
  end

  describe "#playback_url" do
    let(:service) { described_class.new(site) }

    it "returns HLS URL for playback_id" do
      result = service.playback_url("playback-123")
      expect(result).to eq("https://stream.mux.com/playback-123.m3u8")
    end

    it "returns nil for blank playback_id" do
      expect(service.playback_url(nil)).to be_nil
      expect(service.playback_url("")).to be_nil
    end
  end

  describe "#disable_stream" do
    let(:service) { described_class.new(site) }
    let(:mock_live_streams_api) { instance_double(MuxRuby::LiveStreamsApi) }

    before do
      allow(MuxRuby::LiveStreamsApi).to receive(:new).and_return(mock_live_streams_api)
      allow(mock_live_streams_api).to receive(:disable_live_stream)
    end

    it "disables the stream" do
      expect(mock_live_streams_api).to receive(:disable_live_stream).with("stream-123")

      result = service.disable_stream("stream-123")
      expect(result).to be true
    end

    context "when Mux API fails" do
      before do
        allow(mock_live_streams_api).to receive(:disable_live_stream)
          .and_raise(MuxRuby::ApiError.new(message: "API error"))
      end

      it "raises MuxApiError" do
        expect {
          service.disable_stream("stream-123")
        }.to raise_error(MuxLiveStreamService::MuxApiError, /Failed to disable Mux stream/)
      end
    end
  end

  describe "#enable_stream" do
    let(:service) { described_class.new(site) }
    let(:mock_live_streams_api) { instance_double(MuxRuby::LiveStreamsApi) }

    before do
      allow(MuxRuby::LiveStreamsApi).to receive(:new).and_return(mock_live_streams_api)
      allow(mock_live_streams_api).to receive(:enable_live_stream)
    end

    it "enables the stream" do
      expect(mock_live_streams_api).to receive(:enable_live_stream).with("stream-123")

      result = service.enable_stream("stream-123")
      expect(result).to be true
    end

    context "when Mux API fails" do
      before do
        allow(mock_live_streams_api).to receive(:enable_live_stream)
          .and_raise(MuxRuby::ApiError.new(message: "API error"))
      end

      it "raises MuxApiError" do
        expect {
          service.enable_stream("stream-123")
        }.to raise_error(MuxLiveStreamService::MuxApiError, /Failed to enable Mux stream/)
      end
    end
  end

  describe "#delete_stream" do
    let(:service) { described_class.new(site) }
    let(:mock_live_streams_api) { instance_double(MuxRuby::LiveStreamsApi) }

    before do
      allow(MuxRuby::LiveStreamsApi).to receive(:new).and_return(mock_live_streams_api)
      allow(mock_live_streams_api).to receive(:delete_live_stream)
    end

    it "deletes the stream" do
      expect(mock_live_streams_api).to receive(:delete_live_stream).with("stream-123")

      result = service.delete_stream("stream-123")
      expect(result).to be true
    end

    context "when Mux API fails" do
      before do
        allow(mock_live_streams_api).to receive(:delete_live_stream)
          .and_raise(MuxRuby::ApiError.new(message: "API error"))
      end

      it "raises MuxApiError" do
        expect {
          service.delete_stream("stream-123")
        }.to raise_error(MuxLiveStreamService::MuxApiError, /Failed to delete Mux stream/)
      end
    end
  end

  describe "#get_asset" do
    let(:service) { described_class.new(site) }
    let(:mock_asset) do
      double("MuxRuby::Asset",
        playback_ids: [ double(id: "playback-123") ],
        status: "ready",
        duration: 3600.5)
    end
    let(:mock_response) { double("MuxRuby::AssetResponse", data: mock_asset) }
    let(:mock_assets_api) { instance_double(MuxRuby::AssetsApi) }

    before do
      allow(MuxRuby::AssetsApi).to receive(:new).and_return(mock_assets_api)
      allow(mock_assets_api).to receive(:get_asset).and_return(mock_response)
    end

    it "returns asset details" do
      result = service.get_asset("asset-123")

      expect(result[:playback_id]).to eq("playback-123")
      expect(result[:status]).to eq("ready")
      expect(result[:duration]).to eq(3600.5)
    end

    context "when Mux API fails" do
      before do
        allow(mock_assets_api).to receive(:get_asset)
          .and_raise(MuxRuby::ApiError.new(message: "API error"))
      end

      it "raises MuxApiError" do
        expect {
          service.get_asset("asset-123")
        }.to raise_error(MuxLiveStreamService::MuxApiError, /Failed to get Mux asset/)
      end
    end
  end

  describe "#get_stream" do
    let(:service) { described_class.new(site) }
    let(:mock_stream) do
      double("MuxRuby::LiveStream",
        status: "active",
        active_asset_id: "asset-123",
        playback_ids: [ double(id: "playback-456") ])
    end
    let(:mock_response) { double("MuxRuby::LiveStreamResponse", data: mock_stream) }
    let(:mock_live_streams_api) { instance_double(MuxRuby::LiveStreamsApi) }

    before do
      allow(MuxRuby::LiveStreamsApi).to receive(:new).and_return(mock_live_streams_api)
      allow(mock_live_streams_api).to receive(:get_live_stream).and_return(mock_response)
    end

    it "returns stream details" do
      result = service.get_stream("stream-123")

      expect(result[:status]).to eq("active")
      expect(result[:active_asset_id]).to eq("asset-123")
      expect(result[:playback_id]).to eq("playback-456")
    end

    context "when Mux API fails" do
      before do
        allow(mock_live_streams_api).to receive(:get_live_stream)
          .and_raise(MuxRuby::ApiError.new(message: "API error"))
      end

      it "raises MuxApiError" do
        expect {
          service.get_stream("stream-123")
        }.to raise_error(MuxLiveStreamService::MuxApiError, /Failed to get Mux stream/)
      end
    end
  end
end
