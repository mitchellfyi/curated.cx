# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LiveStreams", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first }
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /live_streams" do
    let!(:public_scheduled) { create(:live_stream, :scheduled, site: site, user: admin_user, visibility: :public_access) }
    let!(:public_live) { create(:live_stream, :live, site: site, user: admin_user, visibility: :public_access) }
    let!(:subscribers_only) { create(:live_stream, :scheduled, :subscribers_only, site: site, user: admin_user) }

    it "returns the index page" do
      get live_streams_path

      expect(response).to have_http_status(:success)
    end

    context "when user is signed in" do
      before { sign_in user }

      it "shows public streams" do
        get live_streams_path

        expect(assigns(:live_streams)).to include(public_scheduled, public_live)
      end
    end

    context "when user is not signed in" do
      it "shows public streams" do
        get live_streams_path

        expect(assigns(:live_streams)).to include(public_scheduled, public_live)
      end
    end
  end

  describe "GET /live_streams/:id" do
    let(:live_stream) { create(:live_stream, :live, :with_mux, site: site, user: admin_user, visibility: :public_access) }

    it "returns the show page" do
      get live_stream_path(live_stream)

      expect(response).to have_http_status(:success)
      expect(assigns(:live_stream)).to eq(live_stream)
    end

    context "with subscribers only stream" do
      let(:subscribers_only_stream) { create(:live_stream, :live, :subscribers_only, site: site, user: admin_user) }

      context "when user is not signed in" do
        it "redirects to login" do
          get live_stream_path(subscribers_only_stream)

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in but not subscribed" do
        before { sign_in user }

        it "redirects with unauthorized message" do
          get live_stream_path(subscribers_only_stream)

          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq(I18n.t("auth.unauthorized"))
        end
      end

      context "when user is admin" do
        before { sign_in admin_user }

        it "shows the stream" do
          get live_stream_path(subscribers_only_stream)

          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "POST /live_streams/:id/join" do
    let(:live_stream) { create(:live_stream, :live, :with_mux, site: site, user: admin_user) }

    context "when user is signed in" do
      before { sign_in user }

      it "creates a viewer record" do
        expect {
          post join_live_stream_path(live_stream)
        }.to change(LiveStreamViewer, :count).by(1)
      end

      it "updates viewer count" do
        post join_live_stream_path(live_stream)

        live_stream.reload
        expect(live_stream.viewer_count).to eq(1)
      end

      it "responds to HTML format" do
        post join_live_stream_path(live_stream)

        expect(response).to redirect_to(live_stream_path(live_stream))
      end
    end

    context "when user is not signed in" do
      it "returns unprocessable content" do
        post join_live_stream_path(live_stream)

        # Without a user or valid session, the viewer creation fails validation
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "POST /live_streams/:id/leave" do
    let(:live_stream) { create(:live_stream, :live, :with_mux, site: site, user: admin_user) }

    context "when user is signed in" do
      before { sign_in user }

      let!(:viewer) { create(:live_stream_viewer, live_stream: live_stream, site: site, user: user, left_at: nil) }

      it "marks the viewer as left" do
        post leave_live_stream_path(live_stream)

        viewer.reload
        expect(viewer.left_at).to be_present
      end

      it "updates viewer count" do
        live_stream.update!(viewer_count: 1)

        post leave_live_stream_path(live_stream)

        live_stream.reload
        expect(live_stream.viewer_count).to eq(0)
      end

      it "responds to HTML format" do
        post leave_live_stream_path(live_stream)

        expect(response).to redirect_to(live_streams_path)
      end
    end
  end
end
