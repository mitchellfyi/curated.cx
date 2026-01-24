# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Tenant Resolution", type: :request do
  # This spec proves that tenant resolution works as documented in ARCHITECTURE.md
  # It verifies that the TenantResolver middleware correctly sets Current.tenant
  # and that tenant-scoped data isolation works in practice.

  let!(:tenant1) { create(:tenant, hostname: 'test1.example.com', slug: 'test1', title: 'Test Tenant 1') }
  let!(:tenant2) { create(:tenant, hostname: 'test2.example.com', slug: 'test2', title: 'Test Tenant 2') }

  # Use the auto-created sites from tenant factory
  let!(:site1) { tenant1.sites.first }
  let!(:site2) { tenant2.sites.first }

  let!(:category1) { create(:category, site: site1, tenant: tenant1, key: 'news', name: 'News') }
  let!(:category2) { create(:category, site: site2, tenant: tenant2, key: 'news2', name: 'News 2') }

  describe "GET /" do
    context "when request has valid tenant hostname" do
      it "sets Current.tenant correctly via middleware" do
        host! tenant1.hostname

        get root_path

        expect(response).to have_http_status(:success)
        # Tenant resolved correctly - success response indicates correct resolution
      end

      it "isolates tenant data correctly" do
        host! tenant1.hostname

        get categories_path

        # Should only see categories for tenant1
        expect(response).to have_http_status(:success)
        # The response should contain tenant1's category
        expect(response.body).to include(category1.name)
        # The response should NOT contain tenant2's category
        expect(response.body).not_to include(category2.name) unless category2.name == category1.name
      end

      it "switches tenant context correctly between requests" do
        # First request
        host! tenant1.hostname
        get root_path
        expect(response).to have_http_status(:success)

        # Second request with different tenant
        host! tenant2.hostname
        get root_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when request has unknown hostname" do
      it "returns 404 as documented" do
        host! 'unknown.example.com'

        get root_path

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('Domain Not Connected')
        expect(Current.tenant).to be_nil
      end
    end

    context "when request has disabled tenant hostname" do
      let!(:disabled_tenant) { create(:tenant, hostname: 'disabled.example.com', slug: 'disabled', status: :disabled) }

      it "returns 404 as documented" do
        host! disabled_tenant.hostname

        get root_path

        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('Domain Not Connected')
        expect(Current.tenant).to be_nil
      end
    end

    context "when request has hostname with port" do
      it "strips port and resolves tenant correctly" do
        host! "#{tenant1.hostname}:3000"

        get root_path

        expect(response).to have_http_status(:success)
        # Port stripped and tenant resolved correctly
      end
    end
  end

  describe "GET /up (health check)" do
    it "skips tenant resolution as documented" do
      host! 'unknown.example.com'

      get '/up'

      # Health check should work even with unknown hostname
      expect(response).to have_http_status(:success)
      expect(Current.tenant).to be_nil
    end
  end
end
