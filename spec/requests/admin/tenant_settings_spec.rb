# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::TenantSettings", type: :request do
  let!(:tenant) { create(:tenant, :ai_news) }
  let(:admin_user) { create(:user, :admin) }
  let(:owner_user) { create(:user) }
  let(:regular_user) { create(:user) }

  before do
    owner_user.add_role(:owner, tenant)
  end

  shared_context "tenant context" do
    before do
      host! tenant.hostname
      setup_tenant_context(tenant)
    end
  end

  describe "GET /admin/tenant_settings" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "renders successfully" do
        get admin_tenant_settings_path
        expect(response).to have_http_status(:success)
      end

      it "assigns the current tenant" do
        get admin_tenant_settings_path
        expect(assigns(:tenant)).to eq(tenant)
      end

      it "assigns sites and domains" do
        get admin_tenant_settings_path
        expect(assigns(:sites)).to be_a(ActiveRecord::Relation)
        expect(assigns(:domains)).to be_a(ActiveRecord::Relation)
      end

      it "displays tenant settings form" do
        get admin_tenant_settings_path
        expect(response.body).to include("Tenant Settings")
        expect(response.body).to include(tenant.title)
      end
    end

    context "as tenant owner" do
      before { sign_in owner_user }

      it "renders successfully" do
        get admin_tenant_settings_path
        expect(response).to have_http_status(:success)
      end
    end

    context "as regular user" do
      before { sign_in regular_user }

      it "denies access" do
        get admin_tenant_settings_path
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "PATCH /admin/tenant_settings" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "updates tenant column attributes" do
        patch admin_tenant_settings_path, params: { tenant: { title: "Updated Name" } }
        expect(response).to redirect_to(admin_tenant_settings_path)
        expect(tenant.reload.title).to eq("Updated Name")
      end

      it "updates tenant JSONB settings" do
        patch admin_tenant_settings_path, params: { tenant: { twitter_handle: "@newhandle" } }
        expect(response).to redirect_to(admin_tenant_settings_path)
        expect(tenant.reload.setting("twitter_handle")).to eq("@newhandle")
      end

      it "re-renders on validation error" do
        patch admin_tenant_settings_path, params: { tenant: { title: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "as tenant owner" do
      before { sign_in owner_user }

      it "updates tenant settings" do
        patch admin_tenant_settings_path, params: { tenant: { meta_title: "New Meta" } }
        expect(response).to redirect_to(admin_tenant_settings_path)
        expect(tenant.reload.setting("meta_title")).to eq("New Meta")
      end
    end

    context "as regular user" do
      before { sign_in regular_user }

      it "denies access" do
        patch admin_tenant_settings_path, params: { tenant: { title: "Hacked" } }
        expect(response).to have_http_status(:redirect)
        expect(tenant.reload.title).not_to eq("Hacked")
      end
    end
  end
end
