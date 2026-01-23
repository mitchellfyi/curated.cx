# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Taxonomies", type: :request do
  let!(:tenant1) { create(:tenant, :ai_news) }
  let!(:tenant2) { create(:tenant, :construction) }
  let!(:site1) { create(:site, tenant: tenant1, slug: "ai_site", name: "AI Site") }
  let!(:site2) { create(:site, tenant: tenant2, slug: "construction_site", name: "Construction Site") }
  let(:admin_user) { create(:user, :admin) }
  let(:tenant1_owner) { create(:user) }
  let(:tenant2_owner) { create(:user) }

  before do
    tenant1_owner.add_role(:owner, tenant1)
    tenant2_owner.add_role(:owner, tenant2)
  end

  describe "tenant scoping" do
    before do
      @tenant1_taxonomy = create(:taxonomy, tenant: tenant1, site: site1, name: "Tech Taxonomy")
      @tenant2_taxonomy = create(:taxonomy, tenant: tenant2, site: site2, name: "Construction Taxonomy")
    end

    context "when accessing as admin user" do
      before { sign_in admin_user }

      context "with tenant1 context" do
        before do
          host! tenant1.hostname
          setup_tenant_context(tenant1)
        end

        describe "GET /admin/taxonomies" do
          it "only shows taxonomies for the current tenant" do
            get admin_taxonomies_path
            expect(response).to have_http_status(:success)
            expect(assigns(:taxonomies)).to include(@tenant1_taxonomy)
            expect(assigns(:taxonomies)).not_to include(@tenant2_taxonomy)
          end
        end

        describe "GET /admin/taxonomies/:id" do
          it "can access taxonomy from current tenant" do
            get admin_taxonomy_path(@tenant1_taxonomy)
            expect(response).to have_http_status(:success)
            expect(assigns(:taxonomy)).to eq(@tenant1_taxonomy)
          end

          it "cannot access taxonomy from different tenant" do
            get admin_taxonomy_path(@tenant2_taxonomy)
            expect(response).to have_http_status(:not_found)
          end
        end

        describe "GET /admin/taxonomies/new" do
          it "renders new form" do
            get new_admin_taxonomy_path
            expect(response).to have_http_status(:success)
            expect(assigns(:taxonomy)).to be_a_new(Taxonomy)
          end
        end

        describe "POST /admin/taxonomies" do
          it "creates taxonomy for current tenant" do
            expect {
              post admin_taxonomies_path, params: {
                taxonomy: {
                  name: "New Taxonomy",
                  slug: "new-taxonomy",
                  description: "A new taxonomy"
                }
              }
            }.to change { site1.taxonomies.count }.by(1)

            new_taxonomy = site1.taxonomies.last
            expect(new_taxonomy.name).to eq("New Taxonomy")
            expect(new_taxonomy.tenant).to eq(tenant1)
            expect(new_taxonomy.site).to eq(site1)
          end

          it "redirects to show on success" do
            post admin_taxonomies_path, params: {
              taxonomy: { name: "Test", slug: "test" }
            }
            expect(response).to redirect_to(admin_taxonomy_path(Taxonomy.last))
          end

          it "renders new with errors on invalid params" do
            post admin_taxonomies_path, params: {
              taxonomy: { name: "", slug: "" }
            }
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        describe "GET /admin/taxonomies/:id/edit" do
          it "can edit taxonomy from current tenant" do
            get edit_admin_taxonomy_path(@tenant1_taxonomy)
            expect(response).to have_http_status(:success)
            expect(assigns(:taxonomy)).to eq(@tenant1_taxonomy)
          end

          it "cannot edit taxonomy from different tenant" do
            get edit_admin_taxonomy_path(@tenant2_taxonomy)
            expect(response).to have_http_status(:not_found)
          end
        end

        describe "PATCH /admin/taxonomies/:id" do
          it "updates taxonomy" do
            patch admin_taxonomy_path(@tenant1_taxonomy), params: {
              taxonomy: { name: "Updated Name" }
            }
            expect(@tenant1_taxonomy.reload.name).to eq("Updated Name")
            expect(response).to redirect_to(admin_taxonomy_path(@tenant1_taxonomy))
          end

          it "renders edit with errors on invalid params" do
            patch admin_taxonomy_path(@tenant1_taxonomy), params: {
              taxonomy: { name: "" }
            }
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        describe "DELETE /admin/taxonomies/:id" do
          it "destroys taxonomy" do
            expect {
              delete admin_taxonomy_path(@tenant1_taxonomy)
            }.to change { Taxonomy.count }.by(-1)
            expect(response).to redirect_to(admin_taxonomies_path)
          end

          it "cannot destroy taxonomy from different tenant" do
            expect {
              delete admin_taxonomy_path(@tenant2_taxonomy)
            }.not_to change { Taxonomy.count }
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      context "with tenant2 context" do
        before do
          host! tenant2.hostname
          setup_tenant_context(tenant2)
        end

        describe "GET /admin/taxonomies" do
          it "only shows taxonomies for the current tenant" do
            get admin_taxonomies_path
            expect(response).to have_http_status(:success)
            expect(assigns(:taxonomies)).to include(@tenant2_taxonomy)
            expect(assigns(:taxonomies)).not_to include(@tenant1_taxonomy)
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

        describe "GET /admin/taxonomies" do
          it "only shows taxonomies for the current tenant" do
            get admin_taxonomies_path
            expect(response).to have_http_status(:success)
            expect(assigns(:taxonomies)).to include(@tenant1_taxonomy)
            expect(assigns(:taxonomies)).not_to include(@tenant2_taxonomy)
          end
        end

        describe "POST /admin/taxonomies" do
          it "creates taxonomy for current tenant" do
            expect {
              post admin_taxonomies_path, params: {
                taxonomy: {
                  name: "Owner Created",
                  slug: "owner-created"
                }
              }
            }.to change { site1.taxonomies.count }.by(1)

            new_taxonomy = site1.taxonomies.last
            expect(new_taxonomy.tenant).to eq(tenant1)
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

        describe "GET /admin/taxonomies" do
          it "redirects with access denied" do
            get admin_taxonomies_path
            expect(response).to redirect_to(root_path)
            expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
          end
        end
      end
    end
  end

  describe "hierarchy features" do
    let(:admin_user) { create(:user, :admin) }

    before do
      sign_in admin_user
      host! tenant1.hostname
      setup_tenant_context(tenant1)
    end

    describe "creating child taxonomy" do
      let!(:parent) { create(:taxonomy, tenant: tenant1, site: site1, name: "Parent") }

      it "allows setting parent_id" do
        post admin_taxonomies_path, params: {
          taxonomy: {
            name: "Child",
            slug: "child",
            parent_id: parent.id
          }
        }

        child = Taxonomy.find_by(slug: "child")
        expect(child.parent).to eq(parent)
      end
    end

    describe "showing taxonomy" do
      let!(:parent) { create(:taxonomy, :with_children, tenant: tenant1, site: site1) }

      it "includes children in show view" do
        get admin_taxonomy_path(parent)
        expect(assigns(:children)).to be_present
        expect(assigns(:children).first.parent).to eq(parent)
      end
    end
  end
end
