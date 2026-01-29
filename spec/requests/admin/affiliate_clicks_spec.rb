# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::AffiliateClicks", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:category) { create(:category, site: site, tenant: tenant) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    sign_in admin_user
  end

  describe "GET /admin/affiliate_clicks" do
    context "when there are no clicks" do
      it "returns http success" do
        get admin_affiliate_clicks_path

        expect(response).to have_http_status(:success)
      end

      it "shows empty state" do
        get admin_affiliate_clicks_path

        expect(response.body).to include(I18n.t("admin.affiliate_clicks.no_clicks"))
      end
    end

    context "when there are clicks" do
      let!(:listing) { create(:listing, site: site, category: category, affiliate_url_template: "https://example.com?ref=123") }
      let!(:clicks) do
        [
          create(:affiliate_click, listing: listing, clicked_at: 1.day.ago),
          create(:affiliate_click, listing: listing, clicked_at: 2.days.ago),
          create(:affiliate_click, listing: listing, clicked_at: 3.days.ago)
        ]
      end

      it "returns http success" do
        get admin_affiliate_clicks_path

        expect(response).to have_http_status(:success)
      end

      it "shows click statistics" do
        get admin_affiliate_clicks_path

        expect(response.body).to include("3") # total clicks
      end

      it "shows top listings" do
        get admin_affiliate_clicks_path

        expect(response.body).to include(listing.title)
      end
    end

    context "with period filter" do
      let!(:listing) { create(:listing, site: site, category: category, affiliate_url_template: "https://example.com?ref=123") }

      before do
        create(:affiliate_click, listing: listing, clicked_at: 2.days.ago)
        create(:affiliate_click, listing: listing, clicked_at: 20.days.ago)
        create(:affiliate_click, listing: listing, clicked_at: 60.days.ago)
      end

      it "filters by 7 day period" do
        get admin_affiliate_clicks_path(period: "7d")

        expect(assigns(:stats)[:total_clicks]).to eq(1)
      end

      it "filters by 30 day period" do
        get admin_affiliate_clicks_path(period: "30d")

        expect(assigns(:stats)[:total_clicks]).to eq(2)
      end

      it "filters by 90 day period" do
        get admin_affiliate_clicks_path(period: "90d")

        expect(assigns(:stats)[:total_clicks]).to eq(3)
      end
    end

    context "with category filter" do
      let(:other_category) { create(:category, site: site, tenant: tenant) }
      let!(:listing1) { create(:listing, site: site, category: category, affiliate_url_template: "https://example.com?ref=123") }
      let!(:listing2) { create(:listing, site: site, category: other_category, affiliate_url_template: "https://example.com?ref=456") }

      before do
        create(:affiliate_click, listing: listing1, clicked_at: 1.day.ago)
        create(:affiliate_click, listing: listing1, clicked_at: 2.days.ago)
        create(:affiliate_click, listing: listing2, clicked_at: 1.day.ago)
      end

      it "filters by category" do
        get admin_affiliate_clicks_path(category_id: category.id)

        expect(assigns(:stats)[:total_clicks]).to eq(2)
      end
    end
  end

  describe "GET /admin/affiliate_clicks/export" do
    let!(:listing) { create(:listing, site: site, category: category, affiliate_url_template: "https://example.com?ref=123") }
    let!(:click) { create(:affiliate_click, listing: listing, clicked_at: 1.day.ago, referrer: "https://google.com", user_agent: "Mozilla/5.0") }

    it "returns CSV file" do
      get export_admin_affiliate_clicks_path(format: :csv)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
    end

    it "includes click data in CSV" do
      get export_admin_affiliate_clicks_path(format: :csv)

      expect(response.body).to include("Date")
      expect(response.body).to include("Listing")
      expect(response.body).to include(listing.title)
    end

    it "sets appropriate filename" do
      get export_admin_affiliate_clicks_path(format: :csv)

      expect(response.headers["Content-Disposition"]).to include("affiliate_clicks")
    end
  end

  describe "authorization" do
    context "when not signed in" do
      before { sign_out admin_user }

      it "redirects to sign in" do
        get admin_affiliate_clicks_path

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
        get admin_affiliate_clicks_path

        # AdminAccess concern raises Pundit::NotAuthorizedError which is rescued to redirect
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
