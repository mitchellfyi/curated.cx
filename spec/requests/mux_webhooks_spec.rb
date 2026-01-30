# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MuxWebhooks", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first }
  let(:user) { create(:user, :admin) }
  let(:webhook_secret) { "test_webhook_secret" }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    allow(Rails.application.config).to receive(:mux).and_return({
      token_id: "test_token_id",
      token_secret: "test_token_secret",
      webhook_secret: webhook_secret
    })
  end

  def generate_signature(payload, timestamp: Time.now.to_i)
    signed_payload = "#{timestamp}.#{payload}"
    signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, signed_payload)
    "t=#{timestamp},v1=#{signature}"
  end

  describe "POST /webhooks/mux" do
    let(:live_stream) { create(:live_stream, :scheduled, :with_mux, site: site, user: user) }
    let(:payload) do
      {
        type: "video.live_stream.active",
        data: { id: live_stream.mux_stream_id }
      }.to_json
    end

    context "with valid signature" do
      it "returns success" do
        post webhooks_mux_path,
             params: payload,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_MUX_SIGNATURE" => generate_signature(payload)
             }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ "received" => true })
      end

      it "processes the event" do
        expect {
          post webhooks_mux_path,
               params: payload,
               headers: {
                 "CONTENT_TYPE" => "application/json",
                 "HTTP_MUX_SIGNATURE" => generate_signature(payload)
               }
        }.to change { live_stream.reload.status }.from("scheduled").to("live")
      end
    end

    context "with invalid signature" do
      it "returns bad request" do
        post webhooks_mux_path,
             params: payload,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_MUX_SIGNATURE" => "t=123,v1=invalid_signature"
             }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ "error" => "Invalid signature" })
      end
    end

    context "with missing signature" do
      it "returns bad request" do
        post webhooks_mux_path,
             params: payload,
             headers: { "CONTENT_TYPE" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with invalid JSON payload" do
      it "returns bad request" do
        invalid_payload = "not valid json"
        post webhooks_mux_path,
             params: invalid_payload,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_MUX_SIGNATURE" => generate_signature(invalid_payload)
             }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ "error" => "Invalid payload" })
      end
    end

    context "without webhook secret configured" do
      let(:webhook_secret) { nil }

      before do
        allow(Rails.application.config).to receive(:mux).and_return({
          token_id: "test_token_id",
          token_secret: "test_token_secret",
          webhook_secret: nil
        })
      end

      it "skips signature verification in development" do
        post webhooks_mux_path,
             params: payload,
             headers: { "CONTENT_TYPE" => "application/json" }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with video.live_stream.idle event" do
      let(:live_stream) { create(:live_stream, :live, :with_mux, site: site, user: user) }
      let(:payload) do
        {
          type: "video.live_stream.idle",
          data: { id: live_stream.mux_stream_id }
        }.to_json
      end

      it "ends the stream" do
        post webhooks_mux_path,
             params: payload,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_MUX_SIGNATURE" => generate_signature(payload)
             }

        expect(response).to have_http_status(:ok)
        expect(live_stream.reload.status_ended?).to be true
      end
    end

    context "with video.asset.ready event" do
      let(:live_stream) { create(:live_stream, :ended, :with_mux, site: site, user: user) }
      let(:passthrough) { { site_id: site.id, title: live_stream.title }.to_json }
      let(:payload) do
        {
          type: "video.asset.ready",
          data: {
            id: "asset-123",
            passthrough: passthrough,
            live_stream_id: live_stream.mux_stream_id,
            playback_ids: [ { id: "replay-playback-456" } ]
          }
        }.to_json
      end

      it "updates the replay info" do
        post webhooks_mux_path,
             params: payload,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_MUX_SIGNATURE" => generate_signature(payload)
             }

        expect(response).to have_http_status(:ok)
        live_stream.reload
        expect(live_stream.mux_asset_id).to eq("asset-123")
        expect(live_stream.replay_playback_id).to eq("replay-playback-456")
      end
    end

    context "with unhandled event type" do
      let(:payload) do
        {
          type: "video.unknown.event",
          data: {}
        }.to_json
      end

      it "returns success" do
        post webhooks_mux_path,
             params: payload,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_MUX_SIGNATURE" => generate_signature(payload)
             }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
