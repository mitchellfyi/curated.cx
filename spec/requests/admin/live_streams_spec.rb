# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::LiveStreams", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  before do
    site.update_setting("streaming.enabled", true)
    sign_in admin_user
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /admin/live_streams" do
    let!(:live_stream1) { create(:live_stream, :scheduled, site: site, user: admin_user) }
    let!(:live_stream2) { create(:live_stream, :live, site: site, user: admin_user) }

    it "returns a list of live streams" do
      get admin_live_streams_path

      expect(response).to have_http_status(:success)
      expect(assigns(:live_streams)).to include(live_stream1, live_stream2)
    end

    context "when not admin" do
      before { sign_in regular_user }

      it "redirects with access denied" do
        get admin_live_streams_path

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /admin/live_streams/:id" do
    let(:live_stream) { create(:live_stream, :with_mux, site: site, user: admin_user) }

    it "returns the live stream details" do
      get admin_live_stream_path(live_stream)

      expect(response).to have_http_status(:success)
      expect(assigns(:live_stream)).to eq(live_stream)
    end

    context "when stream is from another site" do
      let(:other_tenant) { create(:tenant) }
      let(:other_site) { other_tenant.sites.first }
      let(:other_stream) do
        ActsAsTenant.without_tenant do
          create(:live_stream, site: other_site, user: create(:user))
        end
      end

      it "returns not found" do
        get admin_live_stream_path(other_stream)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /admin/live_streams/new" do
    it "renders the new form" do
      get new_admin_live_stream_path

      expect(response).to have_http_status(:success)
      expect(assigns(:live_stream)).to be_a_new(LiveStream)
    end

    context "when streaming is disabled" do
      before do
        site.update_setting("streaming.enabled", false)
        Current.site.reload
      end

      it "redirects with disabled message" do
        get new_admin_live_stream_path

        expect(response).to redirect_to(admin_live_streams_path)
        expect(flash[:alert]).to eq(I18n.t("admin.live_streams.disabled"))
      end
    end
  end

  describe "POST /admin/live_streams" do
    let(:mock_mux_service) { instance_double(MuxLiveStreamService) }
    let(:mux_response) do
      {
        mux_stream_id: "mux-stream-123",
        mux_playback_id: "playback-456",
        stream_key: "secret-key-789"
      }
    end

    before do
      allow(MuxLiveStreamService).to receive(:new).and_return(mock_mux_service)
      allow(mock_mux_service).to receive(:create_stream).and_return(mux_response)
    end

    let(:valid_params) do
      {
        live_stream: {
          title: "Test Stream",
          description: "A test stream",
          scheduled_at: 1.hour.from_now,
          visibility: "public_access"
        }
      }
    end

    it "creates a new live stream" do
      expect {
        post admin_live_streams_path, params: valid_params
      }.to change(LiveStream, :count).by(1)
    end

    it "creates an associated discussion" do
      expect {
        post admin_live_streams_path, params: valid_params
      }.to change(Discussion, :count).by(1)
    end

    it "stores Mux credentials" do
      post admin_live_streams_path, params: valid_params

      live_stream = LiveStream.last
      expect(live_stream.mux_stream_id).to eq("mux-stream-123")
      expect(live_stream.mux_playback_id).to eq("playback-456")
      expect(live_stream.stream_key).to eq("secret-key-789")
    end

    it "redirects to show page with success notice" do
      post admin_live_streams_path, params: valid_params

      expect(response).to redirect_to(admin_live_stream_path(LiveStream.last))
      expect(flash[:notice]).to eq(I18n.t("admin.live_streams.created"))
    end

    context "when Mux is not configured" do
      before do
        allow(mock_mux_service).to receive(:create_stream)
          .and_raise(MuxLiveStreamService::MuxNotConfiguredError, "Not configured")
      end

      it "renders new with error" do
        post admin_live_streams_path, params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash.now[:alert]).to eq(I18n.t("admin.live_streams.mux_not_configured"))
      end
    end

    context "when Mux API fails" do
      before do
        allow(mock_mux_service).to receive(:create_stream)
          .and_raise(MuxLiveStreamService::MuxApiError, "API Error")
      end

      it "renders new with error" do
        post admin_live_streams_path, params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with invalid params" do
      it "renders new with errors" do
        post admin_live_streams_path, params: { live_stream: { title: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when streaming is disabled" do
      before do
        site.update_setting("streaming.enabled", false)
        Current.site.reload
      end

      it "redirects with disabled message" do
        post admin_live_streams_path, params: valid_params

        expect(response).to redirect_to(admin_live_streams_path)
      end
    end
  end

  describe "GET /admin/live_streams/:id/edit" do
    let(:live_stream) { create(:live_stream, site: site, user: admin_user) }

    it "renders the edit form" do
      get edit_admin_live_stream_path(live_stream)

      expect(response).to have_http_status(:success)
      expect(assigns(:live_stream)).to eq(live_stream)
    end
  end

  describe "PATCH /admin/live_streams/:id" do
    let(:live_stream) { create(:live_stream, site: site, user: admin_user) }

    it "updates the live stream" do
      patch admin_live_stream_path(live_stream), params: {
        live_stream: { title: "Updated Title" }
      }

      live_stream.reload
      expect(live_stream.title).to eq("Updated Title")
    end

    it "redirects with success notice" do
      patch admin_live_stream_path(live_stream), params: {
        live_stream: { title: "Updated Title" }
      }

      expect(response).to redirect_to(admin_live_stream_path(live_stream))
      expect(flash[:notice]).to eq(I18n.t("admin.live_streams.updated"))
    end

    context "with invalid params" do
      it "renders edit with errors" do
        patch admin_live_stream_path(live_stream), params: {
          live_stream: { title: "" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/live_streams/:id" do
    let!(:live_stream) { create(:live_stream, :with_mux, site: site, user: admin_user) }
    let(:mock_mux_service) { instance_double(MuxLiveStreamService) }

    before do
      allow(MuxLiveStreamService).to receive(:new).and_return(mock_mux_service)
      allow(mock_mux_service).to receive(:delete_stream)
    end

    it "deletes the live stream" do
      expect {
        delete admin_live_stream_path(live_stream)
      }.to change(LiveStream, :count).by(-1)
    end

    it "calls Mux to delete the stream" do
      expect(mock_mux_service).to receive(:delete_stream).with(live_stream.mux_stream_id)

      delete admin_live_stream_path(live_stream)
    end

    it "redirects with success notice" do
      delete admin_live_stream_path(live_stream)

      expect(response).to redirect_to(admin_live_streams_path)
      expect(flash[:notice]).to eq(I18n.t("admin.live_streams.destroyed"))
    end

    context "when Mux delete fails" do
      before do
        allow(mock_mux_service).to receive(:delete_stream)
          .and_raise(MuxLiveStreamService::MuxApiError, "API Error")
      end

      it "still deletes the local record" do
        expect {
          delete admin_live_stream_path(live_stream)
        }.to change(LiveStream, :count).by(-1)
      end
    end
  end

  describe "POST /admin/live_streams/:id/start" do
    let(:live_stream) { create(:live_stream, :scheduled, site: site, user: admin_user) }

    it "starts the stream" do
      post start_admin_live_stream_path(live_stream)

      live_stream.reload
      expect(live_stream.status_live?).to be true
      expect(live_stream.started_at).to be_present
    end

    it "redirects with success notice" do
      post start_admin_live_stream_path(live_stream)

      expect(response).to redirect_to(admin_live_stream_path(live_stream))
      expect(flash[:notice]).to eq(I18n.t("admin.live_streams.started"))
    end

    context "when stream cannot start" do
      let(:live_stream) { create(:live_stream, :live, site: site, user: admin_user) }

      it "redirects with error" do
        post start_admin_live_stream_path(live_stream)

        expect(response).to redirect_to(admin_live_stream_path(live_stream))
        expect(flash[:alert]).to eq(I18n.t("admin.live_streams.cannot_start"))
      end
    end
  end

  describe "POST /admin/live_streams/:id/end_stream" do
    let(:live_stream) { create(:live_stream, :live, site: site, user: admin_user) }
    let!(:active_viewer) { create(:live_stream_viewer, live_stream: live_stream, site: site, left_at: nil) }

    it "ends the stream" do
      post end_stream_admin_live_stream_path(live_stream)

      live_stream.reload
      expect(live_stream.status_ended?).to be true
      expect(live_stream.ended_at).to be_present
    end

    it "marks all active viewers as left" do
      post end_stream_admin_live_stream_path(live_stream)

      active_viewer.reload
      expect(active_viewer.left_at).to be_present
    end

    it "redirects with success notice" do
      post end_stream_admin_live_stream_path(live_stream)

      expect(response).to redirect_to(admin_live_stream_path(live_stream))
      expect(flash[:notice]).to eq(I18n.t("admin.live_streams.ended"))
    end

    context "when stream cannot end" do
      let(:live_stream) { create(:live_stream, :scheduled, site: site, user: admin_user) }

      it "redirects with error" do
        post end_stream_admin_live_stream_path(live_stream)

        expect(response).to redirect_to(admin_live_stream_path(live_stream))
        expect(flash[:alert]).to eq(I18n.t("admin.live_streams.cannot_end"))
      end
    end
  end
end
