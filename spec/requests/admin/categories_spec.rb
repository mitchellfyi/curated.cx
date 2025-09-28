require 'rails_helper'

RSpec.describe "Admin::Categories", type: :request do
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

    context "when accessing as admin user" do
      before { sign_in admin_user }

      context "with tenant1 context" do
        before { Current.tenant = tenant1 }

        describe "GET /admin/categories" do
          it "only shows categories for the current tenant" do
            get admin_categories_path
            expect(response).to have_http_status(:success)
            expect(assigns(:categories)).to include(tenant1_category)
            expect(assigns(:categories)).not_to include(tenant2_category)
          end
        end

        describe "GET /admin/categories/:id" do
          it "can access category from current tenant" do
            get admin_category_path(tenant1_category)
            expect(response).to have_http_status(:success)
            expect(assigns(:category)).to eq(tenant1_category)
          end

          it "cannot access category from different tenant" do
            expect {
              get admin_category_path(tenant2_category)
            }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        describe "GET /admin/categories/:id/edit" do
          it "can edit category from current tenant" do
            get edit_admin_category_path(tenant1_category)
            expect(response).to have_http_status(:success)
            expect(assigns(:category)).to eq(tenant1_category)
          end

          it "cannot edit category from different tenant" do
            expect {
              get edit_admin_category_path(tenant2_category)
            }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end

      context "with tenant2 context" do
        before { Current.tenant = tenant2 }

        describe "GET /admin/categories" do
          it "only shows categories for the current tenant" do
            get admin_categories_path
            expect(response).to have_http_status(:success)
            expect(assigns(:categories)).to include(tenant2_category)
            expect(assigns(:categories)).not_to include(tenant1_category)
          end
        end
      end
    end

    context "when accessing as tenant owner" do
      before { sign_in tenant1_owner }

      context "with tenant1 context" do
        before { Current.tenant = tenant1 }

        describe "GET /admin/categories" do
          it "only shows categories for the current tenant" do
            get admin_categories_path
            expect(response).to have_http_status(:success)
            expect(assigns(:categories)).to include(tenant1_category)
            expect(assigns(:categories)).not_to include(tenant2_category)
          end
        end

        describe "POST /admin/categories" do
          it "creates category for current tenant" do
            expect {
              post admin_categories_path, params: {
                category: {
                  key: "new_category",
                  name: "New Category",
                  allow_paths: true,
                  shown_fields: { title: true }
                }
              }
            }.to change { tenant1.categories.count }.by(1)
              .and not_change { tenant2.categories.count }

            new_category = tenant1.categories.last
            expect(new_category.key).to eq("new_category")
            expect(new_category.name).to eq("New Category")
          end
        end
      end
    end

    context "when accessing without proper permissions" do
      let(:regular_user) { create(:user) }
      before { sign_in regular_user }

      context "with tenant1 context" do
        before { Current.tenant = tenant1 }

        describe "GET /admin/categories" do
          it "redirects with access denied" do
            get admin_categories_path
            expect(response).to redirect_to(root_path)
            expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
          end
        end
      end
    end
  end
end
