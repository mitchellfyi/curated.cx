# frozen_string_literal: true

require "rails_helper"

RSpec.describe MuxWebhookHandler do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }

  before do
    Current.site = site
  end

  describe "#process" do
    context "with video.live_stream.active event" do
      let(:live_stream) { create(:live_stream, :scheduled, :with_mux, site: site, user: user) }
      let(:event) do
        {
          type: "video.live_stream.active",
          data: {
            id: live_stream.mux_stream_id
          }
        }
      end

      it "updates the stream status to live" do
        described_class.new(event).process

        live_stream.reload
        expect(live_stream.status_live?).to be true
      end

      it "sets started_at to current time" do
        freeze_time do
          described_class.new(event).process

          live_stream.reload
          expect(live_stream.started_at).to eq(Time.current)
        end
      end

      context "when site has notifications enabled" do
        before do
          allow(site).to receive(:streaming_notify_on_live?).and_return(true)
        end

        it "queues notification job" do
          expect(NotifyLiveStreamSubscribersJob).to receive(:perform_later).with(live_stream.id)

          described_class.new(event).process
        end
      end

      context "when site has notifications disabled" do
        before do
          site.update_setting("streaming.notify_on_live", false)
        end

        it "does not queue notification job" do
          expect(NotifyLiveStreamSubscribersJob).not_to receive(:perform_later)

          described_class.new(event).process
        end
      end

      context "when stream is not found" do
        let(:event) do
          {
            type: "video.live_stream.active",
            data: { id: "non-existent-stream" }
          }
        end

        it "returns true without error" do
          expect(described_class.new(event).process).to be true
        end
      end
    end

    context "with video.live_stream.idle event" do
      let(:live_stream) { create(:live_stream, :live, :with_mux, site: site, user: user) }
      let!(:active_viewer) { create(:live_stream_viewer, live_stream: live_stream, site: site, user: create(:user), left_at: nil) }
      let(:event) do
        {
          type: "video.live_stream.idle",
          data: {
            id: live_stream.mux_stream_id
          }
        }
      end

      it "updates the stream status to ended" do
        described_class.new(event).process

        live_stream.reload
        expect(live_stream.status_ended?).to be true
      end

      it "sets ended_at to current time" do
        freeze_time do
          described_class.new(event).process

          live_stream.reload
          expect(live_stream.ended_at).to eq(Time.current)
        end
      end

      it "marks all active viewers as left" do
        described_class.new(event).process

        active_viewer.reload
        expect(active_viewer.left_at).to be_present
        expect(active_viewer.duration_seconds).to be_present
      end

      context "when stream is not live" do
        let(:live_stream) { create(:live_stream, :scheduled, :with_mux, site: site, user: user) }

        it "does not update the stream" do
          expect {
            described_class.new(event).process
          }.not_to change { live_stream.reload.status }
        end
      end

      context "when stream is not found" do
        let(:event) do
          {
            type: "video.live_stream.idle",
            data: { id: "non-existent-stream" }
          }
        end

        it "returns true without error" do
          expect(described_class.new(event).process).to be true
        end
      end
    end

    context "with video.asset.ready event" do
      let(:live_stream) { create(:live_stream, :ended, :with_mux, site: site, user: user) }
      let(:passthrough) { { site_id: site.id, title: live_stream.title }.to_json }
      let(:event) do
        {
          type: "video.asset.ready",
          data: {
            id: "asset-123",
            passthrough: passthrough,
            live_stream_id: live_stream.mux_stream_id,
            playback_ids: [ { id: "replay-playback-456" } ]
          }
        }
      end

      it "updates the live stream with asset info" do
        described_class.new(event).process

        live_stream.reload
        expect(live_stream.mux_asset_id).to eq("asset-123")
        expect(live_stream.replay_playback_id).to eq("replay-playback-456")
      end

      context "when passthrough is missing" do
        let(:passthrough) { nil }

        it "returns true without updating the stream" do
          expect(described_class.new(event).process).to be true

          live_stream.reload
          expect(live_stream.mux_asset_id).to be_nil
        end
      end

      context "when passthrough has site_id but no title" do
        let(:passthrough) { { site_id: site.id }.to_json }

        it "uses live_stream_id fallback" do
          described_class.new(event).process

          live_stream.reload
          expect(live_stream.mux_asset_id).to eq("asset-123")
        end
      end

      context "when stream is not found" do
        let(:event) do
          {
            type: "video.asset.ready",
            data: {
              id: "asset-123",
              passthrough: nil,
              live_stream_id: "non-existent-stream",
              playback_ids: [ { id: "playback-456" } ]
            }
          }
        end

        it "returns true without error" do
          expect(described_class.new(event).process).to be true
        end
      end
    end

    context "with unhandled event type" do
      let(:event) do
        {
          type: "video.unknown.event",
          data: {}
        }
      end

      it "logs and returns true" do
        expect(Rails.logger).to receive(:info).with(/Unhandled Mux event type/)

        expect(described_class.new(event).process).to be true
      end
    end
  end
end
