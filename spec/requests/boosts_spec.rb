# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Boosts", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source_site) do
    s = create(:site, tenant: tenant)
    create(:domain, :primary, site: s)
    s
  end
  let(:target_site) { site }
  let(:boost) { create(:network_boost, source_site: source_site, target_site: target_site) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /boosts/:id/click" do
    it "redirects to the source site" do
      get boost_click_path(boost)

      expect(response).to have_http_status(:redirect)
    end

    it "tracks the click" do
      expect {
        get boost_click_path(boost)
      }.to change(BoostClick, :count).by(1)
    end

    it "stores click metadata" do
      get boost_click_path(boost)

      click = BoostClick.last
      expect(click.network_boost).to eq(boost)
      expect(click.ip_hash).to be_present
      expect(click.clicked_at).to be_within(1.second).of(Time.current)
      expect(click.earned_amount).to eq(boost.cpc_rate)
    end

    it "updates boost spending" do
      expect {
        get boost_click_path(boost)
      }.to change { boost.reload.spent_this_month }.by(boost.cpc_rate)
    end

    context "when same IP clicks within 24 hours" do
      before do
        get boost_click_path(boost)
      end

      it "still redirects" do
        get boost_click_path(boost)
        expect(response).to have_http_status(:redirect)
      end

      it "does not create a duplicate click (deduplication)" do
        expect {
          get boost_click_path(boost)
        }.not_to change(BoostClick, :count)
      end
    end

    context "with non-existent boost" do
      it "returns not found" do
        get boost_click_path(id: 999_999)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when source site has no domain" do
      let(:source_site_no_domain) { create(:site, tenant: tenant) }
      let(:boost_no_domain) { create(:network_boost, source_site: source_site_no_domain, target_site: target_site) }

      it "redirects to root URL" do
        get boost_click_path(boost_no_domain)

        expect(response).to have_http_status(:redirect)
        expect(response.location).to eq(root_url)
      end
    end

    context "public access" do
      it "does not require authentication" do
        get boost_click_path(boost)

        expect(response).to have_http_status(:redirect)
        expect(response.location).not_to include("sign_in")
      end
    end
  end
end
