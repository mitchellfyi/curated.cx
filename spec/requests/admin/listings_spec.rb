require 'rails_helper'

RSpec.describe "Admin::Listings", type: :request do
  let(:tenant1) { create(:tenant, :ai_news) }
  let(:tenant2) { create(:tenant, :construction) }
  let(:admin_user) { create(:user, :admin) }
  let(:tenant1_owner) { create(:user) }
  let(:tenant2_owner) { create(:user) }

  before do
    # Set up roles
    tenant1_owner.add_role(:owner, tenant1)
    tenant2_owner.add_role(:owner, tenant2)
  end

  describe "tenant scoping" do
    let!(:tenant1_category) { create(:category, :news, tenant: tenant1) }
    let!(:tenant2_category) { create(:category, :news, tenant: tenant2) }
    let!(:tenant1_listing) { create(:listing, category: tenant1_category, tenant: tenant1) }
    let!(:tenant2_listing) { create(:listing, category: tenant2_category, tenant: tenant2) }

    context "when accessing as admin user" do
      before { sign_in admin_user }

      context "with tenant1 context" do
        before { Current.tenant = tenant1 }

        describe "GET /admin/listings" do
          it "only shows listings for the current tenant" do
            get admin_listings_path
            expect(response).to have_http_status(:success)
            expect(assigns(:listings)).to include(tenant1_listing)
            expect(assigns(:listings)).not_to include(tenant2_listing)
          end

          it "only shows categories for the current tenant" do
            get admin_listings_path
            expect(response).to have_http_status(:success)
            expect(assigns(:categories)).to include(tenant1_category)
            expect(assigns(:categories)).not_to include(tenant2_category)
          end
        end

        describe "GET /admin/listings/:id" do
          it "can access listing from current tenant" do
            get admin_listing_path(tenant1_listing)
            expect(response).to have_http_status(:success)
            expect(assigns(:listing)).to eq(tenant1_listing)
          end

          it "cannot access listing from different tenant" do
            expect {
              get admin_listing_path(tenant2_listing)
            }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        describe "GET /admin/listings/:id/edit" do
          it "can edit listing from current tenant" do
            get edit_admin_listing_path(tenant1_listing)
            expect(response).to have_http_status(:success)
            expect(assigns(:listing)).to eq(tenant1_listing)
            expect(assigns(:categories)).to include(tenant1_category)
            expect(assigns(:categories)).not_to include(tenant2_category)
          end

          it "cannot edit listing from different tenant" do
            expect {
              get edit_admin_listing_path(tenant2_listing)
            }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        describe "GET /admin/listings/new" do
          it "only shows categories for the current tenant" do
            get new_admin_listing_path
            expect(response).to have_http_status(:success)
            expect(assigns(:categories)).to include(tenant1_category)
            expect(assigns(:categories)).not_to include(tenant2_category)
          end
        end
      end

      context "with tenant2 context" do
        before { Current.tenant = tenant2 }

        describe "GET /admin/listings" do
          it "only shows listings for the current tenant" do
            get admin_listings_path
            expect(response).to have_http_status(:success)
            expect(assigns(:listings)).to include(tenant2_listing)
            expect(assigns(:listings)).not_to include(tenant1_listing)
          end
        end
      end
    end

    context "when accessing as tenant owner" do
      before { sign_in tenant1_owner }

      context "with tenant1 context" do
        before { Current.tenant = tenant1 }

        describe "GET /admin/listings" do
          it "only shows listings for the current tenant" do
            get admin_listings_path
            expect(response).to have_http_status(:success)
            expect(assigns(:listings)).to include(tenant1_listing)
            expect(assigns(:listings)).not_to include(tenant2_listing)
          end
        end

        describe "POST /admin/listings" do
          it "creates listing for current tenant" do
            expect {
              post admin_listings_path, params: {
                listing: {
                  category_id: tenant1_category.id,
                  url_raw: "https://example.com/test",
                  title: "Test Listing",
                  description: "Test description"
                }
              }
            }.to change { tenant1.listings.count }.by(1)
              .and not_change { tenant2.listings.count }

            new_listing = tenant1.listings.last
            expect(new_listing.title).to eq("Test Listing")
            expect(new_listing.category).to eq(tenant1_category)
          end
        end
      end
    end

    context "when accessing without proper permissions" do
      let(:regular_user) { create(:user) }
      before { sign_in regular_user }

      context "with tenant1 context" do
        before { Current.tenant = tenant1 }

        describe "GET /admin/listings" do
          it "redirects with access denied" do
            get admin_listings_path
            expect(response).to redirect_to(root_path)
            expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
          end
        end
      end
    end
  end
end
