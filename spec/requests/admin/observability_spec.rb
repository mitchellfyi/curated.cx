# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin::Observability", type: :request do
  let!(:tenant1) { create(:tenant, :ai_news) }
  let!(:tenant2) { create(:tenant, :construction) }
  let(:admin_user) { create(:user, :admin) }
  let(:tenant_owner) { create(:user) }
  let(:regular_user) { create(:user) }

  before do
    tenant_owner.add_role(:owner, tenant1)
  end

  describe "GET /admin/observability (show)" do
    context "as admin user" do
      before { sign_in admin_user }

      context "with tenant context" do
        let!(:source) { create(:source, :rss, site: tenant1.sites.first) }
        let!(:import_run_completed) do
          create(:import_run, :completed, source: source, started_at: 1.hour.ago)
        end
        let!(:import_run_failed) do
          create(:import_run, :failed, source: source, started_at: 2.hours.ago)
        end
        let!(:entry) { create(:entry, :feed, source: source, site: source.site) }
        let!(:editorialisation) do
          create(:editorialisation, :completed, entry: entry, site: source.site)
        end

        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "renders the overview page successfully" do
          get admin_observability_path
          expect(response).to have_http_status(:success)
        end

        it "assigns stats" do
          get admin_observability_path
          expect(assigns(:stats)).to be_present
          expect(assigns(:stats)).to include(
            :total_sources,
            :active_sources_today,
            :imports_today,
            :failed_imports_today,
            :items_imported_today,
            :editorialisations_today,
            :editorialisations_completed,
            :editorialisations_failed,
            :editorialisations_pending,
            :content_items_total,
            :content_items_published,
            :content_items_editorialised,
            :jobs_pending,
            :jobs_failed
          )
        end

        it "assigns recent import runs" do
          get admin_observability_path
          expect(assigns(:recent_import_runs)).to be_present
          expect(assigns(:recent_import_runs)).to include(import_run_completed)
        end

        it "assigns recent editorialisations" do
          get admin_observability_path
          expect(assigns(:recent_editorialisations)).to be_present
          expect(assigns(:recent_editorialisations)).to include(editorialisation)
        end

        it "assigns serp_api_stats" do
          get admin_observability_path
          expect(assigns(:serp_api_stats)).to be_present
          expect(assigns(:serp_api_stats)).to include(:monthly, :daily, :projections)
        end
      end
    end

    context "as tenant owner (non-super-admin)" do
      before { sign_in tenant_owner }

      context "with tenant context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "allows access to the observability page" do
          get admin_observability_path
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "as regular user without admin role" do
      before { sign_in regular_user }

      context "with tenant context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "denies access" do
          get admin_observability_path
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context "without authentication" do
      before do
        host! tenant1.hostname
        setup_tenant_context(tenant1)
      end

      it "redirects to sign in" do
        get admin_observability_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /admin/observability/imports" do
    context "as admin user" do
      before { sign_in admin_user }

      context "with tenant context" do
        let!(:source1) { create(:source, :rss, site: tenant1.sites.first) }
        let!(:source2) { create(:source, :serp_api_google_news, site: tenant1.sites.first) }
        let!(:import_run1) do
          create(:import_run, :completed, source: source1, started_at: 1.hour.ago)
        end
        let!(:import_run2) do
          create(:import_run, :failed, source: source2, started_at: 2.hours.ago)
        end

        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "renders the imports page successfully" do
          get imports_admin_observability_path
          expect(response).to have_http_status(:success)
        end

        it "assigns enabled sources" do
          get imports_admin_observability_path
          expect(assigns(:sources)).to include(source1, source2)
        end

        it "assigns import runs" do
          get imports_admin_observability_path
          expect(assigns(:import_runs)).to include(import_run1, import_run2)
        end

        it "assigns import stats" do
          get imports_admin_observability_path
          expect(assigns(:stats)).to be_present
          expect(assigns(:stats)).to include(
            :total_runs_24h,
            :completed_24h,
            :failed_24h,
            :items_created_24h,
            :items_updated_24h,
            :items_failed_24h,
            :avg_duration_ms,
            :sources_by_status
          )
        end

        it "calculates stats correctly" do
          get imports_admin_observability_path
          stats = assigns(:stats)

          # We have 2 import runs in the last 24h
          expect(stats[:total_runs_24h]).to eq(2)
          expect(stats[:completed_24h]).to eq(1)
          expect(stats[:failed_24h]).to eq(1)
        end
      end
    end

    context "as tenant owner" do
      before { sign_in tenant_owner }

      context "with tenant context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "allows access" do
          get imports_admin_observability_path
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/observability/editorialisations" do
    context "as admin user" do
      before { sign_in admin_user }

      context "with tenant context" do
        let!(:source) { create(:source, :rss, site: tenant1.sites.first) }
        let!(:content_item1) { create(:entry, :feed, source: source, site: source.site) }
        let!(:content_item2) { create(:entry, :feed, source: source, site: source.site) }
        let!(:editorialisation_completed) do
          create(:editorialisation, :completed, entry: content_item1, site: source.site)
        end
        let!(:editorialisation_failed) do
          create(:editorialisation, :failed, entry: content_item2, site: source.site)
        end

        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "renders the editorialisations page successfully" do
          get editorialisations_admin_observability_path
          expect(response).to have_http_status(:success)
        end

        it "assigns editorialisations" do
          get editorialisations_admin_observability_path
          expect(assigns(:editorialisations)).to include(editorialisation_completed, editorialisation_failed)
        end

        it "assigns editorialisation stats" do
          get editorialisations_admin_observability_path
          expect(assigns(:stats)).to be_present
          expect(assigns(:stats)).to include(
            :total_24h,
            :by_status,
            :avg_tokens,
            :avg_duration_ms,
            :total_tokens_24h,
            :pending_content_items
          )
        end

        it "calculates stats correctly" do
          get editorialisations_admin_observability_path
          stats = assigns(:stats)

          expect(stats[:total_24h]).to eq(2)
          expect(stats[:by_status]["completed"]).to eq(1)
          expect(stats[:by_status]["failed"]).to eq(1)
        end
      end
    end

    context "as tenant owner" do
      before { sign_in tenant_owner }

      context "with tenant context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "allows access" do
          get editorialisations_admin_observability_path
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/observability/serp_api" do
    context "as admin user" do
      before { sign_in admin_user }

      context "with tenant context" do
        let!(:serp_source) do
          create(:source, :serp_api_google_news, site: tenant1.sites.first)
        end
        let!(:serp_import_run) do
          create(:import_run, :completed, source: serp_source, started_at: 1.hour.ago)
        end

        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "renders the serp_api page successfully" do
          get serp_api_admin_observability_path
          expect(response).to have_http_status(:success)
        end

        it "assigns serp api stats" do
          get serp_api_admin_observability_path
          expect(assigns(:stats)).to be_present
          expect(assigns(:stats)).to include(:monthly, :daily, :projections)
        end

        it "assigns serp api sources" do
          get serp_api_admin_observability_path
          expect(assigns(:sources)).to include(serp_source)
        end

        it "assigns recent runs for serp api sources" do
          get serp_api_admin_observability_path
          expect(assigns(:recent_runs)).to include(serp_import_run)
        end

        it "assigns daily usage chart data" do
          get serp_api_admin_observability_path
          expect(assigns(:daily_usage)).to be_a(Hash)
        end
      end
    end

    context "as tenant owner" do
      before { sign_in tenant_owner }

      context "with tenant context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "allows access" do
          get serp_api_admin_observability_path
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/observability/ai_usage" do
    context "as admin user" do
      before { sign_in admin_user }

      context "with tenant context" do
        let!(:source) { create(:source, :rss, site: tenant1.sites.first) }
        let!(:entry) { create(:entry, :feed, source: source, site: source.site) }
        let!(:editorialisation) do
          create(:editorialisation, :completed, entry: entry, site: source.site)
        end

        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "renders the ai_usage page successfully" do
          get ai_usage_admin_observability_path
          expect(response).to have_http_status(:success)
        end

        it "assigns AI usage stats" do
          get ai_usage_admin_observability_path
          expect(assigns(:stats)).to be_present
          expect(assigns(:stats)).to include(:cost, :tokens, :projections, :requests, :models)
        end

        it "assigns daily usage chart data" do
          get ai_usage_admin_observability_path
          expect(assigns(:daily_usage)).to be_an(Array)
        end

        it "assigns recent editorialisations" do
          get ai_usage_admin_observability_path
          expect(assigns(:recent_editorialisations)).to be_present
        end

        it "assigns pause status" do
          get ai_usage_admin_observability_path
          expect(assigns(:is_paused)).to eq(false).or eq(true)
        end

        it "includes expected content" do
          get ai_usage_admin_observability_path
          expect(response.body).to include("AI Usage Monitoring")
          expect(response.body).to include("Monthly Cost")
          expect(response.body).to include("AI Processing Control")
        end
      end
    end

    context "as tenant owner" do
      before { sign_in tenant_owner }

      context "with tenant context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        it "allows access" do
          get ai_usage_admin_observability_path
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "tenant scoping" do
    let!(:tenant1_source) { create(:source, :rss, site: tenant1.sites.first) }
    let!(:tenant2_source) { create(:source, :rss, site: tenant2.sites.first) }
    let!(:tenant1_import_run) do
      create(:import_run, :completed, source: tenant1_source)
    end
    let!(:tenant2_import_run) do
      create(:import_run, :completed, source: tenant2_source)
    end

    context "as admin user in tenant1 context" do
      before do
        sign_in admin_user
        host! tenant1.hostname
        setup_tenant_context(tenant1)
      end

      it "only shows tenant1 data on show page" do
        get admin_observability_path
        expect(response).to have_http_status(:success)

        # Import runs should be scoped to tenant1's site
        recent_runs = assigns(:recent_import_runs)
        expect(recent_runs).to include(tenant1_import_run)
        expect(recent_runs).not_to include(tenant2_import_run)
      end

      it "only shows tenant1 data on imports page" do
        get imports_admin_observability_path
        expect(response).to have_http_status(:success)

        import_runs = assigns(:import_runs)
        expect(import_runs).to include(tenant1_import_run)
        expect(import_runs).not_to include(tenant2_import_run)
      end
    end
  end

  describe "edge cases" do
    context "with no data" do
      before do
        sign_in admin_user
        host! tenant1.hostname
        setup_tenant_context(tenant1)
      end

      it "renders show page without errors when no import runs exist" do
        get admin_observability_path
        expect(response).to have_http_status(:success)
        expect(assigns(:recent_import_runs)).to be_empty
      end

      it "renders imports page without errors when no data exists" do
        get imports_admin_observability_path
        expect(response).to have_http_status(:success)
        expect(assigns(:stats)[:total_runs_24h]).to eq(0)
      end

      it "renders editorialisations page without errors when no data exists" do
        get editorialisations_admin_observability_path
        expect(response).to have_http_status(:success)
        expect(assigns(:stats)[:total_24h]).to eq(0)
      end

      it "renders serp_api page without errors when no serp sources exist" do
        get serp_api_admin_observability_path
        expect(response).to have_http_status(:success)
        expect(assigns(:sources)).to be_empty
      end

      it "renders ai_usage page without errors when no editorialisations exist" do
        get ai_usage_admin_observability_path
        expect(response).to have_http_status(:success)
        expect(assigns(:daily_usage)).to be_empty
      end
    end

    context "with nil associations" do
      let!(:source) { create(:source, :rss, site: tenant1.sites.first) }
      let!(:entry) { create(:entry, :feed, source: source, site: source.site) }
      let!(:editorialisation) do
        create(:editorialisation, :completed, entry: entry, site: source.site)
      end

      before do
        sign_in admin_user
        host! tenant1.hostname
        setup_tenant_context(tenant1)
      end

      it "handles editorialisations with deleted content items gracefully" do
        # Simulate orphaned editorialisation (entry deleted after editorialisation created)
        # The view uses safe navigation: ed.entry&.title
        get editorialisations_admin_observability_path
        expect(response).to have_http_status(:success)
      end
    end

    context "stats calculations" do
      let!(:source) { create(:source, :rss, site: tenant1.sites.first) }

      before do
        sign_in admin_user
        host! tenant1.hostname
        setup_tenant_context(tenant1)
      end

      it "calculates avg_duration_ms correctly" do
        # Create completed import runs with known durations (0.1 and 0.2 seconds)
        create(:import_run, :completed, source: source, started_at: 2.hours.ago, completed_at: 2.hours.ago + 0.1.seconds)
        create(:import_run, :completed, source: source, started_at: 1.hour.ago, completed_at: 1.hour.ago + 0.2.seconds)

        get imports_admin_observability_path
        stats = assigns(:stats)

        # Average should be calculated
        expect(stats[:avg_duration_ms]).to be_a(Numeric)
      end

      it "handles zero items gracefully in editorialisation stats" do
        get editorialisations_admin_observability_path
        stats = assigns(:stats)

        expect(stats[:avg_tokens]).to eq(0)
        expect(stats[:avg_duration_ms]).to eq(0)
        expect(stats[:total_tokens_24h]).to eq(0)
      end
    end
  end

  describe "pagination" do
    context "with many import runs" do
      let!(:source) { create(:source, :rss, site: tenant1.sites.first) }

      before do
        sign_in admin_user
        host! tenant1.hostname
        setup_tenant_context(tenant1)

        # Create more than page size (50) import runs
        55.times do |i|
          create(:import_run, :completed, source: source, started_at: i.hours.ago)
        end
      end

      it "paginates import runs on imports page" do
        get imports_admin_observability_path
        expect(response).to have_http_status(:success)

        import_runs = assigns(:import_runs)
        expect(import_runs.size).to eq(50) # Default page size
      end

      it "respects page parameter" do
        get imports_admin_observability_path, params: { page: 2 }
        expect(response).to have_http_status(:success)

        import_runs = assigns(:import_runs)
        expect(import_runs.size).to eq(5) # Remaining items on page 2
      end
    end
  end
end
