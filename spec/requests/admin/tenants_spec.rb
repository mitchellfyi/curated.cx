# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Tenants", type: :request do
  let!(:tenant1) { create(:tenant, :ai_news) }
  let!(:tenant2) { create(:tenant, :construction) }
  let(:admin_user) { create(:user, :admin) }
  let(:owner_user) { create(:user) }
  let(:regular_user) { create(:user) }

  before do
    owner_user.add_role(:owner, tenant1)
  end

  shared_context "tenant context" do
    before do
      host! tenant1.hostname
      setup_tenant_context(tenant1)
    end
  end

  describe "GET /admin/tenants" do
    include_context "tenant context"

    context "as super admin" do
      before { sign_in admin_user }

      it "renders successfully" do
        get admin_tenants_path
        expect(response).to have_http_status(:success)
      end

      it "lists all tenants" do
        get admin_tenants_path
        expect(assigns(:tenants)).to include(tenant1, tenant2)
      end

      it "assigns global stats" do
        get admin_tenants_path
        stats = assigns(:stats)
        expect(stats).to have_key(:total_tenants)
        expect(stats).to have_key(:total_sites)
        expect(stats).to have_key(:total_entries)
        expect(stats).to have_key(:total_users)
        expect(stats).to have_key(:active_sources)
        expect(stats).to have_key(:failed_imports_today)
        expect(stats).to have_key(:active_pauses)
      end

      it "assigns per-tenant metrics" do
        get admin_tenants_path
        metrics = assigns(:tenant_metrics)
        expect(metrics).to be_a(Hash)
        expect(metrics[tenant1.id]).to have_key(:sites)
        expect(metrics[tenant1.id]).to have_key(:entries)
        expect(metrics[tenant1.id]).to have_key(:sources)
        expect(metrics[tenant1.id]).to have_key(:failed_imports)
      end

      it "supports search" do
        get admin_tenants_path, params: { search: tenant1.title }
        expect(assigns(:tenants)).to include(tenant1)
        expect(assigns(:tenants)).not_to include(tenant2)
      end

      it "displays tenant metrics in the table" do
        get admin_tenants_path
        expect(response.body).to include("Entries")
        expect(response.body).to include("Sources")
      end
    end

    context "as tenant owner (non-admin)" do
      before { sign_in owner_user }

      it "redirects to admin root" do
        get admin_tenants_path
        expect(response).to redirect_to(admin_root_path)
      end
    end
  end

  describe "GET /admin/tenants/:id" do
    include_context "tenant context"

    context "as super admin" do
      before { sign_in admin_user }

      it "renders successfully" do
        get admin_tenant_path(tenant1)
        expect(response).to have_http_status(:success)
      end

      it "assigns tenant data" do
        get admin_tenant_path(tenant1)
        expect(assigns(:tenant)).to eq(tenant1)
        expect(assigns(:sites)).to be_a(ActiveRecord::Relation)
      end
    end
  end
end
