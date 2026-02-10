require 'rails_helper'

RSpec.describe "Admin::Dashboards", type: :request do
  let!(:tenant1) { create(:tenant, :ai_news) }
  let!(:tenant2) { create(:tenant, :construction) }
  let(:admin_user) { create(:user, :admin) }
  let(:tenant1_owner) { create(:user) }

  before do
    tenant1_owner.add_role(:owner, tenant1)
  end

  describe "tenant scoping" do
    let!(:tenant1_category) { create(:category, :news, tenant: tenant1) }
    let!(:tenant2_category) { create(:category, :news, tenant: tenant2) }
    let!(:tenant1_listing) { create(:entry, :directory, category: tenant1_category, tenant: tenant1, published_at: 1.day.ago, created_at: Time.current) }
    let!(:tenant1_listing_today) { create(:entry, :directory, category: tenant1_category, tenant: tenant1, published_at: Time.current, created_at: Time.current) }
    let!(:tenant2_listing) { create(:entry, :directory, category: tenant2_category, tenant: tenant2, published_at: 1.day.ago, created_at: Time.current) }
    let!(:tenant2_listing_yesterday) { create(:entry, :directory, category: tenant2_category, tenant: tenant2, published_at: 2.days.ago, created_at: Time.current) }

    context "when accessing as admin user" do
      before { sign_in admin_user }

      context "with tenant1 context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        describe "GET /admin" do
          it "only shows data for the current tenant" do
            get admin_root_path
            expect(response).to have_http_status(:success)

            # Check that only tenant1 data is shown
            expect(assigns(:categories)).to include(tenant1_category)
            expect(assigns(:categories)).not_to include(tenant2_category)

            expect(assigns(:recent_entries)).to include(tenant1_listing)
            expect(assigns(:recent_entries)).not_to include(tenant2_listing)

            # Check stats are scoped to current tenant
            stats = assigns(:stats)
            expect(stats[:total_categories]).to eq(1) # Only tenant1_category
            expect(stats[:published_listings]).to eq(2) # tenant1_listing + tenant1_listing_today
            expect(stats[:published_listings]).to eq(2) # Both tenant1 entries are published
            expect(stats[:listings_today]).to eq(2) # Both tenant1_listing and tenant1_listing_today are created today
          end

          it "displays tenant-specific title" do
            get admin_root_path
            expect(response.body).to include(tenant1.title)
            expect(response.body).not_to include(tenant2.title)
          end
        end
      end

      context "with tenant2 context" do
        before do
          host! tenant2.hostname
          setup_tenant_context(tenant2)
        end

        describe "GET /admin" do
          it "only shows data for the current tenant" do
            get admin_root_path
            expect(response).to have_http_status(:success)

            # Check that only tenant2 data is shown
            expect(assigns(:categories)).to include(tenant2_category)
            expect(assigns(:categories)).not_to include(tenant1_category)

            expect(assigns(:recent_entries)).to include(tenant2_listing)
            expect(assigns(:recent_entries)).not_to include(tenant1_listing)

            # Check stats are scoped to current tenant
            stats = assigns(:stats)
            expect(stats[:total_categories]).to eq(1) # Only tenant2_category
            expect(stats[:published_listings]).to eq(2) # tenant2_listing + tenant2_listing_yesterday
            expect(stats[:published_listings]).to eq(2) # Both tenant2 entries are published
            expect(stats[:listings_today]).to eq(2) # Both tenant2_listing and tenant2_listing_yesterday are created today
          end
        end
      end
    end

    context "when accessing as tenant owner" do
      before { sign_in tenant1_owner }

      context "with tenant1 context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        describe "GET /admin" do
          it "only shows data for the current tenant" do
            get admin_root_path
            expect(response).to have_http_status(:success)

            # Check that only tenant1 data is shown
            expect(assigns(:categories)).to include(tenant1_category)
            expect(assigns(:categories)).not_to include(tenant2_category)

            expect(assigns(:recent_entries)).to include(tenant1_listing)
            expect(assigns(:recent_entries)).not_to include(tenant2_listing)

            # Check stats are scoped to current tenant
            stats = assigns(:stats)
            expect(stats[:total_categories]).to eq(1)
            expect(stats[:published_listings]).to eq(2)
            expect(stats[:published_listings]).to eq(2)
            expect(stats[:listings_today]).to eq(2) # Both tenant1_listing and tenant1_listing_today are created today
          end
        end
      end
    end

    context "when accessing without proper permissions" do
      let(:regular_user) { create(:user) }
      before { sign_in regular_user }

      context "with tenant1 context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        describe "GET /admin" do
          it "redirects with access denied" do
            get admin_root_path
            expect(response).to redirect_to(root_path)
            expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
          end
        end
      end
    end
  end

  describe "dashboard section cards" do
    before do
      sign_in admin_user
      host! tenant1.hostname
      setup_tenant_context(tenant1)
    end

    describe "GET /admin" do
      it "renders all navigation section cards" do
        get admin_root_path
        expect(response).to have_http_status(:success)

        # Verify all section cards matching sidebar navigation
        expect(response.body).to include("Content")
        expect(response.body).to include("Sources")
        expect(response.body).to include("Commerce")
        expect(response.body).to include("Boosts / Network")
        expect(response.body).to include("Subscribers")
        expect(response.body).to include("Community")
        expect(response.body).to include("Moderation")
        expect(response.body).to include("Taxonomy")
        expect(response.body).to include("System")
        expect(response.body).to include("Settings")
      end

      it "includes system stats for all sections" do
        get admin_root_path
        stats = assigns(:system_stats)

        # Content
        expect(stats).to have_key(:content_items)
        expect(stats).to have_key(:submissions_pending)
        expect(stats).to have_key(:notes)

        # Sources
        expect(stats).to have_key(:sources_enabled)
        expect(stats).to have_key(:sources_total)
        expect(stats).to have_key(:imports_today)
        expect(stats).to have_key(:imports_failed_today)

        # Commerce
        expect(stats).to have_key(:digital_products)
        expect(stats).to have_key(:affiliate_clicks_today)
        expect(stats).to have_key(:live_streams)

        # Boosts
        expect(stats).to have_key(:network_boosts_enabled)
        expect(stats).to have_key(:boost_clicks_total)
        expect(stats).to have_key(:boost_payouts_pending)

        # Subscribers
        expect(stats).to have_key(:digest_subscribers_active)
        expect(stats).to have_key(:email_sequences_enabled)
        expect(stats).to have_key(:referrals)

        # Community
        expect(stats).to have_key(:comments)
        expect(stats).to have_key(:discussions)

        # Moderation
        expect(stats).to have_key(:flags_open)
        expect(stats).to have_key(:site_bans_active)

        # Taxonomy
        expect(stats).to have_key(:taxonomies)
        expect(stats).to have_key(:tagging_rules_enabled)

        # System
        expect(stats).to have_key(:workflow_pauses_active)
        expect(stats).to have_key(:editorialisations_pending)
        expect(stats).to have_key(:editorialisations_failed_today)

        # Settings
        expect(stats).to have_key(:sites)
        expect(stats).to have_key(:domains)
      end

      it "includes super admin stats for admin users" do
        get admin_root_path
        stats = assigns(:system_stats)
        expect(stats).to have_key(:tenants_count)
        expect(response.body).to include("Super Admin")
        expect(response.body).to include("Tenants")
      end

      it "excludes super admin section for tenant owners" do
        sign_in tenant1_owner
        get admin_root_path
        stats = assigns(:system_stats)
        expect(stats).not_to have_key(:tenants_count)
        expect(response.body).not_to include("Super Admin")
      end

      it "renders quick actions" do
        get admin_root_path
        expect(response.body).to include("Quick Actions")
        expect(response.body).to include("Manage Categories")
        expect(response.body).to include("Manage Sources")
        expect(response.body).to include("Observability")
      end

      it "renders recent activity sections" do
        category = create(:category, tenant: tenant1)
        create(:entry, :directory, :published, tenant: tenant1, category: category)
        get admin_root_path
        expect(response.body).to include("Recent Directory Entries")
      end

      it "includes AI usage summary" do
        get admin_root_path
        expect(assigns(:ai_usage)).to be_a(Hash)
        expect(response.body).to include("AI Usage")
      end

      it "includes SerpAPI usage summary" do
        get admin_root_path
        expect(assigns(:serp_api_usage)).to be_a(Hash)
        expect(response.body).to include("SerpAPI Usage")
      end
    end
  end
end
