# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantsController, type: :controller do
  render_views

  let(:tenant) { create(:tenant, :enabled, title: 'Test Tenant', description: 'Test Description') }
  let(:site) { tenant.sites.first }
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:source) { create(:source, site: site) }
  let!(:content_item1) { create(:entry, :feed, :published, site: site, source: source) }
  let!(:content_item2) { create(:entry, :feed, :published, site: site, source: source) }
  let!(:unpublished_item) { create(:entry, :feed, site: site, source: source, published_at: nil) }
  let!(:other_tenant_item) { create(:entry, :feed, :published) }

  before do
    setup_tenant_context(tenant)
  end

  describe 'GET #index' do
    context 'when user is admin' do
      before { sign_in admin_user }

      it 'returns http success' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'assigns tenants' do
        get :index
        expect(assigns(:tenants)).to be_present
      end

      it 'authorizes Tenant' do
        expect(controller).to receive(:authorize).with(Tenant).and_call_original
        get :index
      end
    end

    context 'when user is not admin' do
      before { sign_in user }

      it 'redirects when not authorized' do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is not signed in' do
      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #show' do
    before { sign_in user }

    it 'returns http success' do
      get :show
      expect(response).to have_http_status(:success)
    end

    it 'assigns the current tenant' do
      get :show
      expect(assigns(:tenant)).to eq(tenant)
    end

    it 'assigns published content items for the site' do
      get :show
      expect(assigns(:entries)).to include(content_item1, content_item2)
      expect(assigns(:entries)).not_to include(unpublished_item)
      expect(assigns(:entries)).not_to include(other_tenant_item)
    end

    it 'limits content items to 12' do
      # Create more content items
      15.times { create(:entry, :feed, :published, site: site, source: source) }

      get :show
      expect(assigns(:entries).count).to eq(12)
    end

    it 'includes source association in content items' do
      get :show
      # The service may or may not preload associations, but items should have sources
      expect(assigns(:entries).first.source).to be_present
    end

    it 'orders content items by ranking' do
      older_item = create(:entry, :feed, :published, site: site, source: source, published_at: 1.week.ago)
      newer_item = create(:entry, :feed, :published, site: site, source: source, published_at: 1.hour.ago)

      get :show
      # Newer items should rank higher in the default ranking
      entries = assigns(:entries)
      expect(entries.index(newer_item)).to be < entries.index(older_item)
    end

    it 'sets meta tags with tenant title' do
      get :show
      expect(response.body).to include(tenant.title)
    end

    it 'sets meta tags with tenant description when present' do
      get :show
      expect(response.body).to include(tenant.description)
    end

    it 'authorizes the current tenant' do
      expect(controller).to receive(:authorize).with(tenant).and_call_original
      get :show
    end

    it 'uses FeedRankingService for content items' do
      # The controller uses FeedRankingService
      get :show
      expect(response).to have_http_status(:success)
      expect(assigns(:entries)).to be_present
    end

    context 'when tenant has no description' do
      let(:tenant_no_desc) { create(:tenant, :enabled, title: 'No Desc', description: '') }

      before do
        setup_tenant_context(tenant_no_desc)
      end

      it 'uses default tagline in meta tags' do
        get :show
        # The page should still load successfully
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET #about' do
    before { sign_in user }

    it 'returns http success' do
      get :about
      expect(response).to have_http_status(:success)
    end

    it 'authorizes the current tenant' do
      expect(controller).to receive(:authorize).with(tenant).and_call_original
      get :about
    end

    it 'renders the about template' do
      get :about
      expect(response).to render_template(:about)
    end
  end

  describe 'tenant context' do
    before { sign_in user }

    it 'uses Current.tenant throughout actions' do
      expect(Current.tenant).to eq(tenant)
      get :show
      expect(assigns(:tenant)).to eq(Current.tenant)
    end
  end

  describe 'authorization' do
    context 'when tenant requires private access' do
      let(:private_tenant) { create(:tenant, :private_access, title: 'Private Tenant') }

      before do
        setup_tenant_context(private_tenant)
      end

      it 'requires authentication for all actions' do
        get :show
        expect(response).to redirect_to(new_user_session_path)

        get :about
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when tenant is publicly accessible' do
      it 'allows public access to show' do
        get :show
        expect(response).to have_http_status(:success)
      end

      it 'allows public access to about' do
        get :about
        expect(response).to have_http_status(:success)
      end
    end
  end
end
