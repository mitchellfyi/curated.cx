require 'rails_helper'

RSpec.describe "Tenants", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:disabled_tenant) { create(:tenant, :disabled) }
  let(:private_tenant) { create(:tenant, :private_access) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:category) { create(:category, tenant: tenant) }
  let!(:listings) { create_list(:listing, 5, :published, tenant: tenant, category: category) }

  describe "GET /tenants" do
    context "when user is admin" do
      before { sign_in admin_user }

      it "returns http success" do
        get tenants_path
        expect(response).to have_http_status(:success)
      end

      it "assigns all tenants" do
        get tenants_path
        expect(assigns(:tenants)).to include(tenant, disabled_tenant, private_tenant)
      end

      it "includes categories in the query to prevent N+1" do
        expect_any_instance_of(ActiveRecord::Relation).to receive(:includes).with(:categories).and_call_original
        get tenants_path
      end

      it "renders the index template" do
        get tenants_path
        expect(response).to render_template(:index)
      end
    end

    context "when user is not admin" do
      before { sign_in regular_user }

      it "returns unauthorized" do
        get tenants_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get tenants_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /tenants/:id" do
    context "when tenant is enabled" do
      before { host! tenant.hostname }

      it "returns http success" do
        get tenant_path(tenant)
        expect(response).to have_http_status(:success)
      end

      it "assigns the correct tenant" do
        get tenant_path(tenant)
        expect(assigns(:tenant)).to eq(tenant)
      end

      it "assigns recent published listings" do
        get tenant_path(tenant)
        expect(assigns(:listings)).to match_array(listings)
      end

      it "includes category in listings query to prevent N+1" do
        expect_any_instance_of(ActiveRecord::Relation).to receive(:includes).with(:category).and_call_original
        get tenant_path(tenant)
      end

      it "limits listings to 20" do
        create_list(:listing, 25, :published, tenant: tenant, category: category)
        get tenant_path(tenant)
        expect(assigns(:listings).count).to eq(20)
      end

      it "orders listings by published_at desc" do
        old_listing = create(:listing, :published, tenant: tenant, category: category, published_at: 2.days.ago)
        new_listing = create(:listing, :published, tenant: tenant, category: category, published_at: 1.hour.ago)
        
        get tenant_path(tenant)
        listings = assigns(:listings)
        expect(listings.first).to eq(new_listing)
        expect(listings.last).to eq(old_listing)
      end

      it "only shows published listings" do
        unpublished_listing = create(:listing, :unpublished, tenant: tenant, category: category)
        
        get tenant_path(tenant)
        expect(assigns(:listings)).not_to include(unpublished_listing)
      end

      it "renders the show template" do
        get tenant_path(tenant)
        expect(response).to render_template(:show)
      end

      it "sets correct meta tags" do
        get tenant_path(tenant)
        expect(response.body).to include(tenant.title)
        expect(response.body).to include(tenant.description)
      end
    end

    context "when tenant is disabled" do
      before { host! disabled_tenant.hostname }

      it "returns not found" do
        expect {
          get tenant_path(disabled_tenant)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when tenant requires private access" do
      before { host! private_tenant.hostname }

      context "when user is not signed in" do
        it "redirects to sign in" do
          get tenant_path(private_tenant)
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in but has no access" do
        before { sign_in regular_user }

        it "returns unauthorized" do
          get tenant_path(private_tenant)
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end

      context "when user has access to tenant" do
        before do
          sign_in regular_user
          regular_user.add_role(:viewer, private_tenant)
        end

        it "returns http success" do
          get tenant_path(private_tenant)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /about" do
    context "when tenant is enabled" do
      before { host! tenant.hostname }

      it "returns http success" do
        get about_path
        expect(response).to have_http_status(:success)
      end

      it "renders the about template" do
        get about_path
        expect(response).to render_template(:about)
      end

      it "sets correct meta tags" do
        get about_path
        expect(response.body).to include(tenant.title)
      end
    end

    context "when tenant is disabled" do
      before { host! disabled_tenant.hostname }

      it "returns not found" do
        expect {
          get about_path
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when tenant requires private access" do
      before { host! private_tenant.hostname }

      context "when user is not signed in" do
        it "redirects to sign in" do
          get about_path
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when user is signed in but has no access" do
        before { sign_in regular_user }

        it "returns unauthorized" do
          get about_path
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end

      context "when user has access to tenant" do
        before do
          sign_in regular_user
          regular_user.add_role(:viewer, private_tenant)
        end

        it "returns http success" do
          get about_path
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET / (root path)" do
    context "when tenant is enabled" do
      before { host! tenant.hostname }

      it "returns http success" do
        get root_path
        expect(response).to have_http_status(:success)
      end

      it "renders the show template" do
        get root_path
        expect(response).to render_template(:show)
      end

      it "assigns the correct tenant" do
        get root_path
        expect(assigns(:tenant)).to eq(tenant)
      end

      it "assigns recent published listings" do
        get root_path
        expect(assigns(:listings)).to match_array(listings)
      end
    end

    context "when tenant is disabled" do
      before { host! disabled_tenant.hostname }

      it "returns not found" do
        expect {
          get root_path
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "authorization" do
    it "authorizes tenant access for show action" do
      expect_any_instance_of(TenantPolicy).to receive(:show?).and_return(true)
      host! tenant.hostname
      get tenant_path(tenant)
    end

    it "authorizes tenant access for about action" do
      expect_any_instance_of(TenantPolicy).to receive(:about?).and_return(true)
      host! tenant.hostname
      get about_path
    end

    it "authorizes tenant listing for index action" do
      expect_any_instance_of(TenantPolicy).to receive(:index?).and_return(true)
      sign_in admin_user
      get tenants_path
    end
  end

  describe "meta tags" do
    before { host! tenant.hostname }

    it "sets default meta tags for show action" do
      get tenant_path(tenant)
      expect(response.body).to include(tenant.title)
      expect(response.body).to include(tenant.description)
    end

    it "sets default meta tags for about action" do
      get about_path
      expect(response.body).to include(tenant.title)
    end
  end

  describe "error handling" do
    context "when tenant does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get tenant_path(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when hostname does not match any tenant" do
      before { host! "nonexistent.example.com" }

      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get root_path
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
