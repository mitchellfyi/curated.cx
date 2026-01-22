require 'rails_helper'

RSpec.describe "Categories", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:disabled_tenant) { create(:tenant, :disabled) }
  let(:private_tenant) { create(:tenant, :private_access) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let!(:category1) { create(:category, :news, tenant: tenant) }
  let!(:category2) { create(:category, :apps, tenant: tenant) }
  let!(:other_tenant_category) { create(:category, tenant: disabled_tenant) }
  let!(:private_tenant_category) { create(:category, tenant: private_tenant) }
  let!(:listings1) { create_list(:listing, 3, :published, tenant: tenant, category: category1) }
  let!(:listings2) { create_list(:listing, 2, :app_listing, :published, tenant: tenant) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /categories" do
    context "when user is signed in" do
      before { sign_in regular_user }

      it "returns http success" do
        get categories_path
        expect(response).to have_http_status(:success)
      end

      it "assigns categories for current tenant" do
        get categories_path
        expect(assigns(:categories)).to include(category1, category2)
        expect(assigns(:categories)).not_to include(other_tenant_category)
      end

      it "orders categories by name" do
        category_z = create(:category, name: "Z Category", tenant: tenant)
        category_a = create(:category, name: "A Category", tenant: tenant)

        get categories_path
        categories = assigns(:categories)
        expect(categories.first).to eq(category_a)
        expect(categories.last).to eq(category_z)
      end

      it "includes listings in the query to prevent N+1" do
        expect_any_instance_of(ActiveRecord::Relation).to receive(:includes).with(:listings).and_call_original
        get categories_path
      end

      it "renders the index template" do
        get categories_path
        expect(response).to render_template(:index)
      end

      it "sets correct meta tags" do
        get categories_path
        expect(response.body).to include(I18n.t('categories.index.title'))
        # Tenant title may contain special characters that get HTML-encoded
        expect(response.body).to include(ERB::Util.html_escape(tenant.title))
      end
    end

    context "when user is not signed in" do
      it "allows public access for enabled tenant" do
        get categories_path
        expect(response).to have_http_status(:success)
      end

      it "assigns categories for current tenant" do
        get categories_path
        expect(assigns(:categories)).to include(category1, category2)
        expect(assigns(:categories)).not_to include(other_tenant_category)
      end
    end

    context "when tenant requires private access" do
      before do
        host! private_tenant.hostname
        setup_tenant_context(private_tenant)
      end

      context "when user is not signed in" do
        it "redirects to sign in" do
          get categories_path
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in" do
        before { sign_in regular_user }

        it "allows access" do
          get categories_path
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when tenant is disabled" do
      before do
        host! disabled_tenant.hostname
        setup_tenant_context(disabled_tenant)
      end

      it "returns not found" do
        get categories_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /categories/:id" do
    context "when user is signed in" do
      before { sign_in regular_user }

      it "returns http success" do
        get category_path(category1)
        expect(response).to have_http_status(:success)
      end

      it "assigns the correct category" do
        get category_path(category1)
        expect(assigns(:category)).to eq(category1)
      end

      it "assigns recent listings for the category" do
        get category_path(category1)
        expect(assigns(:listings)).to match_array(listings1)
        expect(assigns(:listings)).not_to include(listings2)
      end

      it "includes category in listings query to prevent N+1" do
        get category_path(category1)
        # Verify that the category association is loaded to prevent N+1 queries
        expect(assigns(:listings).first.association(:category)).to be_loaded
      end

      it "limits listings to 20" do
        create_list(:listing, 25, :published, tenant: tenant, category: category1)
        get category_path(category1)
        expect(assigns(:listings).count).to eq(20)
      end

      it "orders listings by published_at desc" do
        old_listing = create(:listing, :published, tenant: tenant, category: category1, published_at: 2.days.ago)
        new_listing = create(:listing, :published, tenant: tenant, category: category1, published_at: 1.hour.ago)

        get category_path(category1)
        listings = assigns(:listings)
        expect(listings.first).to eq(new_listing)
        expect(listings.last).to eq(old_listing)
      end

      it "only shows published listings" do
        unpublished_listing = create(:listing, :unpublished, tenant: tenant, category: category1)

        get category_path(category1)
        expect(assigns(:listings)).not_to include(unpublished_listing)
      end

      it "renders the show template" do
        get category_path(category1)
        expect(response).to render_template(:show)
      end

      it "sets correct meta tags" do
        get category_path(category1)
        # Category name and tenant title may contain special characters that get HTML-encoded
        expect(response.body).to include(ERB::Util.html_escape(category1.name))
        expect(response.body).to include(ERB::Util.html_escape(tenant.title))
      end

        context "when category belongs to different tenant" do
          it "returns not found" do
            get category_path(other_tenant_category)
            expect(response).to have_http_status(:not_found)
          end
        end

        context "when category does not exist" do
          it "returns not found" do
            get category_path(999999)
            expect(response).to have_http_status(:not_found)
          end
        end
    end

    context "when user is not signed in" do
      it "allows public access for enabled tenant" do
        get category_path(category1)
        expect(response).to have_http_status(:success)
      end

      it "assigns the correct category" do
        get category_path(category1)
        expect(assigns(:category)).to eq(category1)
      end
    end

    context "when tenant requires private access" do
      before do
        host! private_tenant.hostname
        setup_tenant_context(private_tenant)
      end

      context "when user is not signed in" do
        it "redirects to sign in" do
          get category_path(private_tenant_category)
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in" do
        before { sign_in regular_user }

        it "allows access" do
          get category_path(private_tenant_category)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context "when tenant is disabled" do
      before do
        host! disabled_tenant.hostname
        setup_tenant_context(disabled_tenant)
      end

      it "returns not found" do
        get category_path(other_tenant_category)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "authorization" do
    it "authorizes category access for index action" do
      expect_any_instance_of(CategoryPolicy).to receive(:index?).and_return(true)
      sign_in regular_user
      get categories_path
    end

    it "authorizes category access for show action" do
      expect_any_instance_of(CategoryPolicy).to receive(:show?).and_return(true)
      sign_in regular_user
      get category_path(category1)
    end
  end

  describe "policy scoping" do
    before { sign_in regular_user }

    it "scopes categories to current tenant" do
      get categories_path
      categories = assigns(:categories)
      expect(categories.all? { |c| c.tenant_id == tenant.id }).to be true
    end

    it "scopes listings to current tenant" do
      get category_path(category1)
      listings = assigns(:listings)
      expect(listings.all? { |l| l.tenant_id == tenant.id }).to be true
    end
  end

  describe "meta tags" do
    before { sign_in regular_user }

    it "sets correct meta tags for index action" do
      get categories_path
      expect(response.body).to include(I18n.t('categories.index.title'))
      # Names may contain special characters that get HTML-encoded
      expect(response.body).to include(ERB::Util.html_escape(I18n.t('categories.index.description', tenant: tenant.title)))
    end

    it "sets correct meta tags for show action" do
      get category_path(category1)
      # Category name and tenant title may contain special characters that get HTML-encoded
      expect(response.body).to include(ERB::Util.html_escape(category1.name))
      expect(response.body).to include(ERB::Util.html_escape(I18n.t('categories.show.description', category: category1.name, tenant: tenant.title)))
    end
  end

  describe "error handling" do
    before { sign_in regular_user }

    context "when category does not exist" do
      it "returns not found" do
        get category_path(999999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when category belongs to different tenant" do
      it "returns not found" do
        get category_path(other_tenant_category)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "tenant isolation" do
    let!(:other_tenant) do
      ActsAsTenant.without_tenant { create(:tenant, :enabled) }
    end
    let!(:other_site) do
      ActsAsTenant.without_tenant { create(:site, tenant: other_tenant, slug: other_tenant.slug) }
    end
    let!(:other_category) do
      ActsAsTenant.without_tenant { create(:category, tenant: other_tenant, site: other_site) }
    end

    before { sign_in regular_user }

    it "does not show categories from other tenants" do
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      get categories_path
      expect(assigns(:categories)).to include(other_category)
      expect(assigns(:categories)).not_to include(category1, category2)
    end

    it "does not show listings from other tenants" do
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      get category_path(other_category)
      expect(assigns(:listings)).to be_empty
    end
  end
end
