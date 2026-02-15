# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::BusinessClaims", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:category) { create(:category, site: site, tenant: tenant) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    sign_in admin_user
  end

  describe "GET /admin/business_claims" do
    context "when there are no claims" do
      it "returns http success" do
        get admin_business_claims_path

        expect(response).to have_http_status(:success)
      end
    end

    context "when there are claims" do
      let!(:entry) { create(:entry, :directory, site: site, category: category) }
      let!(:claims) do
        [
          create(:business_claim, :verified, entry: entry),
          create(:business_claim, entry: create(:entry, :directory, site: site, category: category)),
          create(:business_claim, :rejected, entry: create(:entry, :directory, site: site, category: category))
        ]
      end

      it "returns http success" do
        get admin_business_claims_path

        expect(response).to have_http_status(:success)
      end

      it "displays all claims" do
        get admin_business_claims_path

        expect(assigns(:claims).size).to eq(3)
      end

      it "eager loads entry and user associations" do
        expect do
          get admin_business_claims_path
        end.not_to exceed_query_limit(15)
      end
    end

    context "with status filter" do
      let!(:entry1) { create(:entry, :directory, site: site, category: category) }
      let!(:entry2) { create(:entry, :directory, site: site, category: category) }
      let!(:pending_claim) { create(:business_claim, entry: entry1) }
      let!(:verified_claim) { create(:business_claim, :verified, entry: entry2) }

      it "filters by pending status" do
        get admin_business_claims_path(status: "pending")

        expect(assigns(:claims)).to include(pending_claim)
        expect(assigns(:claims)).not_to include(verified_claim)
      end

      it "filters by verified status" do
        get admin_business_claims_path(status: "verified")

        expect(assigns(:claims)).to include(verified_claim)
        expect(assigns(:claims)).not_to include(pending_claim)
      end
    end
  end

  describe "GET /admin/business_claims/:id" do
    let!(:entry) { create(:entry, :directory, site: site, category: category) }
    let!(:claim) { create(:business_claim, :email_verification, entry: entry) }

    it "returns http success" do
      get admin_business_claim_path(claim)

      expect(response).to have_http_status(:success)
    end

    it "displays claim details" do
      get admin_business_claim_path(claim)

      expect(response.body).to include(claim.entry.title)
      expect(response.body).to include(claim.user.email)
    end

    it "prevents N+1 queries by eager loading" do
      expect do
        get admin_business_claim_path(claim)
      end.not_to exceed_query_limit(10)
    end
  end

  describe "POST /admin/business_claims/:id/verify" do
    let!(:entry) { create(:entry, :directory, site: site, category: category) }
    let!(:claim) { create(:business_claim, entry: entry) }

    it "verifies the claim" do
      expect do
        post verify_admin_business_claim_path(claim)
      end.to change { claim.reload.status }.from("pending").to("verified")
    end

    it "sets verified_at timestamp" do
      post verify_admin_business_claim_path(claim)

      expect(claim.reload.verified_at).to be_present
    end

    it "redirects to the claim show page" do
      post verify_admin_business_claim_path(claim)

      expect(response).to redirect_to(admin_business_claim_path(claim))
    end

    it "displays a success notice" do
      post verify_admin_business_claim_path(claim)

      follow_redirect!
      expect(response.body).to include("verified")
    end
  end

  describe "POST /admin/business_claims/:id/reject" do
    let!(:entry) { create(:entry, :directory, site: site, category: category) }
    let!(:claim) { create(:business_claim, entry: entry) }

    it "rejects the claim" do
      expect do
        post reject_admin_business_claim_path(claim)
      end.to change { claim.reload.status }.from("pending").to("rejected")
    end

    it "redirects to the claim show page" do
      post reject_admin_business_claim_path(claim)

      expect(response).to redirect_to(admin_business_claim_path(claim))
    end

    it "displays a success notice" do
      post reject_admin_business_claim_path(claim)

      follow_redirect!
      expect(response.body).to include("rejected")
    end
  end

  describe "authorization" do
    context "when not signed in" do
      before { sign_out admin_user }

      it "redirects to sign in" do
        get admin_business_claims_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      let(:regular_user) { create(:user) }

      before do
        sign_out admin_user
        sign_in regular_user
      end

      it "denies access" do
        get admin_business_claims_path

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "site scoping" do
    let!(:other_tenant) { create(:tenant, :enabled) }
    let!(:other_site) { create(:site, tenant: other_tenant) }
    let!(:other_category) { create(:category, site: other_site, tenant: other_tenant) }
    let!(:other_entry) { create(:entry, :directory, site: other_site, category: other_category) }
    let!(:other_claim) { create(:business_claim, entry: other_entry) }

    it "only shows claims for current site" do
      get admin_business_claims_path

      expect(assigns(:claims)).not_to include(other_claim)
    end

    it "raises not found for claims from other sites" do
      expect do
        get admin_business_claim_path(other_claim)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
