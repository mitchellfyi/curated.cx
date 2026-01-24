# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Sources", type: :request do
  let!(:tenant) { create(:tenant, :ai_news) }
  # Use the site created by the tenant factory
  let!(:site) { tenant.sites.first }
  let(:admin_user) { create(:user, :admin) }
  let(:tenant_owner) { create(:user) }
  let(:regular_user) { create(:user) }

  before do
    tenant_owner.add_role(:owner, tenant)
  end

  describe "tenant scoping" do
    let!(:tenant2) { create(:tenant, :construction) }
    # Use the site created by the tenant2 factory
    let!(:site2) { tenant2.sites.first }
    let!(:tenant1_source) { create(:source, :serp_api_google_news, site: site, name: "AI Source", tenant: tenant) }
    let!(:tenant2_source) do
      ActsAsTenant.without_tenant do
        create(:source, :serp_api_google_news, site: site2, name: "Construction Source", tenant: tenant2)
      end
    end

    context "when accessing as admin user" do
      before { sign_in admin_user }

      context "with tenant context" do
        before do
          host! tenant.hostname
          setup_tenant_context(tenant)
        end

        describe "GET /admin/sources" do
          it "only shows sources for the current tenant" do
            get admin_sources_path

            expect(response).to have_http_status(:success)
            expect(assigns(:sources)).to include(tenant1_source)
            expect(assigns(:sources)).not_to include(tenant2_source)
          end
        end

        describe "GET /admin/sources/:id" do
          it "can access source from current tenant" do
            get admin_source_path(tenant1_source)

            expect(response).to have_http_status(:success)
            expect(assigns(:source)).to eq(tenant1_source)
          end

          it "cannot access source from different tenant" do
            get admin_source_path(tenant2_source)

            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end

    context "when accessing as tenant owner" do
      before do
        sign_in tenant_owner
        host! tenant.hostname
        setup_tenant_context(tenant)
      end

      describe "GET /admin/sources" do
        it "only shows sources for the current tenant" do
          get admin_sources_path

          expect(response).to have_http_status(:success)
          expect(assigns(:sources)).to include(tenant1_source)
          expect(assigns(:sources)).not_to include(tenant2_source)
        end
      end
    end
  end

  describe "CRUD operations" do
    before do
      sign_in tenant_owner
      host! tenant.hostname
      setup_tenant_context(tenant)
    end

    describe "GET /admin/sources" do
      let!(:source1) { create(:source, :serp_api_google_news, site: site, name: "Source 1") }
      let!(:source2) { create(:source, :rss, site: site, name: "Source 2") }

      it "returns success and assigns sources" do
        get admin_sources_path

        expect(response).to have_http_status(:success)
        expect(assigns(:sources)).to include(source1, source2)
      end

      it "orders sources by created_at desc" do
        get admin_sources_path

        expect(assigns(:sources).first).to eq(source2) # Most recent
      end
    end

    describe "GET /admin/sources/:id" do
      let!(:source) { create(:source, :serp_api_google_news, site: site) }
      let!(:import_run) { create(:import_run, :completed, source: source) }

      it "returns success and assigns source" do
        get admin_source_path(source)

        expect(response).to have_http_status(:success)
        expect(assigns(:source)).to eq(source)
      end

      it "assigns recent import runs" do
        get admin_source_path(source)

        expect(assigns(:import_runs)).to include(import_run)
      end

      it "assigns rate limiter" do
        get admin_source_path(source)

        expect(assigns(:rate_limiter)).to be_a(SerpApiRateLimiter)
      end
    end

    describe "GET /admin/sources/new" do
      it "returns success and assigns new source" do
        get new_admin_source_path

        expect(response).to have_http_status(:success)
        expect(assigns(:source)).to be_a_new(Source)
      end

      it "sets default kind to serp_api_google_news" do
        get new_admin_source_path

        expect(assigns(:source).kind).to eq("serp_api_google_news")
      end

      it "sets default config with expected keys" do
        get new_admin_source_path

        config = assigns(:source).config
        expect(config.keys).to include("api_key", "query", "location", "language", "max_results", "rate_limit_per_hour")
      end
    end

    describe "POST /admin/sources" do
      let(:valid_params) do
        {
          source: {
            name: "New Source",
            kind: "serp_api_google_news",
            enabled: true,
            config: {
              api_key: "test_key",
              query: "tech news",
              location: "US",
              language: "en",
              max_results: 50,
              rate_limit_per_hour: 10
            }
          }
        }
      end

      it "creates a new source" do
        expect {
          post admin_sources_path, params: valid_params
        }.to change(Source, :count).by(1)
      end

      it "redirects to the source show page" do
        post admin_sources_path, params: valid_params

        expect(response).to redirect_to(admin_source_path(Source.last))
      end

      it "sets flash notice" do
        post admin_sources_path, params: valid_params

        expect(flash[:notice]).to eq(I18n.t("admin.sources.created"))
      end

      context "with invalid params" do
        let(:invalid_params) do
          {
            source: {
              name: "",
              kind: "serp_api_google_news"
            }
          }
        end

        it "does not create a source" do
          expect {
            post admin_sources_path, params: invalid_params
          }.not_to change(Source, :count)
        end

        it "renders new with unprocessable_entity status" do
          post admin_sources_path, params: invalid_params

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe "GET /admin/sources/:id/edit" do
      let!(:source) { create(:source, :serp_api_google_news, site: site) }

      it "returns success and assigns source" do
        get edit_admin_source_path(source)

        expect(response).to have_http_status(:success)
        expect(assigns(:source)).to eq(source)
      end
    end

    describe "PATCH /admin/sources/:id" do
      let!(:source) { create(:source, :serp_api_google_news, site: site) }

      let(:update_params) do
        {
          source: {
            name: "Updated Source Name",
            enabled: false
          }
        }
      end

      it "updates the source" do
        patch admin_source_path(source), params: update_params

        source.reload
        expect(source.name).to eq("Updated Source Name")
        expect(source.enabled).to be false
      end

      it "redirects to the source show page" do
        patch admin_source_path(source), params: update_params

        expect(response).to redirect_to(admin_source_path(source))
      end

      it "sets flash notice" do
        patch admin_source_path(source), params: update_params

        expect(flash[:notice]).to eq(I18n.t("admin.sources.updated"))
      end

      context "with invalid params" do
        let(:invalid_params) do
          {
            source: { name: "" }
          }
        end

        it "does not update the source" do
          patch admin_source_path(source), params: invalid_params

          source.reload
          expect(source.name).not_to be_blank
        end

        it "renders edit with unprocessable_entity status" do
          patch admin_source_path(source), params: invalid_params

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe "DELETE /admin/sources/:id" do
      let!(:source) { create(:source, :serp_api_google_news, site: site) }

      it "destroys the source" do
        expect {
          delete admin_source_path(source)
        }.to change(Source, :count).by(-1)
      end

      it "redirects to sources index" do
        delete admin_source_path(source)

        expect(response).to redirect_to(admin_sources_path)
      end

      it "sets flash notice" do
        delete admin_source_path(source)

        expect(flash[:notice]).to eq(I18n.t("admin.sources.deleted"))
      end
    end
  end

  describe "POST /admin/sources/:id/run_now" do
    before do
      sign_in tenant_owner
      host! tenant.hostname
      setup_tenant_context(tenant)
    end

    let!(:source) { create(:source, :serp_api_google_news, site: site) }

    context "when source is enabled" do
      it "enqueues SerpApiIngestionJob" do
        expect {
          post run_now_admin_source_path(source)
        }.to have_enqueued_job(SerpApiIngestionJob).with(source.id)
      end

      it "redirects to source show page" do
        post run_now_admin_source_path(source)

        expect(response).to redirect_to(admin_source_path(source))
      end

      it "sets flash notice" do
        post run_now_admin_source_path(source)

        expect(flash[:notice]).to eq(I18n.t("admin.sources.run_queued"))
      end
    end

    context "when source is disabled" do
      let!(:source) { create(:source, :serp_api_google_news, :disabled, site: site) }

      it "does not enqueue job" do
        expect {
          post run_now_admin_source_path(source)
        }.not_to have_enqueued_job(SerpApiIngestionJob)
      end

      it "redirects with alert" do
        post run_now_admin_source_path(source)

        expect(response).to redirect_to(admin_source_path(source))
        expect(flash[:alert]).to eq(I18n.t("admin.sources.source_disabled"))
      end
    end
  end

  describe "access control" do
    context "when accessing without authentication" do
      before do
        host! tenant.hostname
        setup_tenant_context(tenant)
      end

      it "redirects to login" do
        get admin_sources_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when accessing without admin privileges" do
      before do
        sign_in regular_user
        host! tenant.hostname
        setup_tenant_context(tenant)
      end

      describe "GET /admin/sources" do
        it "redirects with access denied" do
          get admin_sources_path

          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
        end
      end
    end
  end
end
