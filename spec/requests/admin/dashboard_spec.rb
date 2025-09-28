require 'rails_helper'

RSpec.describe "Admin::Dashboards", type: :request do
  let(:tenant1) { create(:tenant, :ai_news) }
  let(:tenant2) { create(:tenant, :construction) }
  let(:admin_user) { create(:user, :admin) }
  let(:tenant1_owner) { create(:user) }

  before do
    tenant1_owner.add_role(:owner, tenant1)
  end

  describe "tenant scoping" do
    let!(:tenant1_category) { create(:category, :news, tenant: tenant1) }
    let!(:tenant2_category) { create(:category, :news, tenant: tenant2) }
    let!(:tenant1_listing) { create(:listing, category: tenant1_category, tenant: tenant1, published_at: 1.day.ago) }
    let!(:tenant1_listing_today) { create(:listing, category: tenant1_category, tenant: tenant1, published_at: Time.current) }
    let!(:tenant2_listing) { create(:listing, category: tenant2_category, tenant: tenant2, published_at: 1.day.ago) }
    let!(:tenant2_listing_today) { create(:listing, category: tenant2_category, tenant: tenant2, published_at: Time.current) }

    context "when accessing as admin user" do
      before { sign_in admin_user }

      context "with tenant1 context" do
        before { Current.tenant = tenant1 }

        describe "GET /admin" do
          it "only shows data for the current tenant" do
            get admin_dashboard_path
            expect(response).to have_http_status(:success)

            # Check that only tenant1 data is shown
            expect(assigns(:categories)).to include(tenant1_category)
            expect(assigns(:categories)).not_to include(tenant2_category)

            expect(assigns(:recent_listings)).to include(tenant1_listing)
            expect(assigns(:recent_listings)).not_to include(tenant2_listing)

            # Check stats are scoped to current tenant
            stats = assigns(:stats)
            expect(stats[:total_categories]).to eq(1) # Only tenant1_category
            expect(stats[:total_listings]).to eq(2) # tenant1_listing + tenant1_listing_today
            expect(stats[:published_listings]).to eq(2) # Both tenant1 listings are published
            expect(stats[:listings_today]).to eq(1) # Only tenant1_listing_today
          end

          it "displays tenant-specific title" do
            get admin_dashboard_path
            expect(response.body).to include(tenant1.title)
            expect(response.body).not_to include(tenant2.title)
          end
        end
      end

      context "with tenant2 context" do
        before { Current.tenant = tenant2 }

        describe "GET /admin" do
          it "only shows data for the current tenant" do
            get admin_dashboard_path
            expect(response).to have_http_status(:success)

            # Check that only tenant2 data is shown
            expect(assigns(:categories)).to include(tenant2_category)
            expect(assigns(:categories)).not_to include(tenant1_category)

            expect(assigns(:recent_listings)).to include(tenant2_listing)
            expect(assigns(:recent_listings)).not_to include(tenant1_listing)

            # Check stats are scoped to current tenant
            stats = assigns(:stats)
            expect(stats[:total_categories]).to eq(1) # Only tenant2_category
            expect(stats[:total_listings]).to eq(2) # tenant2_listing + tenant2_listing_today
            expect(stats[:published_listings]).to eq(2) # Both tenant2 listings are published
            expect(stats[:listings_today]).to eq(1) # Only tenant2_listing_today
          end
        end
      end
    end

    context "when accessing as tenant owner" do
      before { sign_in tenant1_owner }

      context "with tenant1 context" do
        before { Current.tenant = tenant1 }

        describe "GET /admin" do
          it "only shows data for the current tenant" do
            get admin_dashboard_path
            expect(response).to have_http_status(:success)

            # Check that only tenant1 data is shown
            expect(assigns(:categories)).to include(tenant1_category)
            expect(assigns(:categories)).not_to include(tenant2_category)

            expect(assigns(:recent_listings)).to include(tenant1_listing)
            expect(assigns(:recent_listings)).not_to include(tenant2_listing)

            # Check stats are scoped to current tenant
            stats = assigns(:stats)
            expect(stats[:total_categories]).to eq(1)
            expect(stats[:total_listings]).to eq(2)
            expect(stats[:published_listings]).to eq(2)
            expect(stats[:listings_today]).to eq(1)
          end
        end
      end
    end

    context "when accessing without proper permissions" do
      let(:regular_user) { create(:user) }
      before { sign_in regular_user }

      context "with tenant1 context" do
        before { Current.tenant = tenant1 }

        describe "GET /admin" do
          it "redirects with access denied" do
            get admin_dashboard_path
            expect(response).to redirect_to(root_path)
            expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
          end
        end
      end
    end
  end
end
