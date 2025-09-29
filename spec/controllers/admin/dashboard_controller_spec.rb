# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::DashboardController, type: :controller do
  let(:tenant) { create(:tenant, :enabled) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:owner_user) { create(:user, :with_tenant_role, role: :owner, tenant: tenant) }

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

      it 'renders the index template' do
        get :index
        expect(response).to render_template(:index)
      end

      it 'assigns decorated tenant' do
        get :index
        expect(assigns(:tenant)).to be_decorated
        expect(assigns(:tenant)).to eq(tenant)
      end

      it 'assigns categories with listings' do
        category = create(:category, tenant: tenant)
        listing = create(:listing, tenant: tenant, category: category)

        get :index
        expect(assigns(:categories)).to include(category)
        expect(assigns(:categories).first.association(:listings)).to be_loaded
      end

      it 'assigns recent listings with categories' do
        listing = create(:listing, tenant: tenant)

        get :index
        expect(assigns(:recent_listings)).to include(listing)
        expect(assigns(:recent_listings).first.association(:category)).to be_loaded
      end

      it 'limits recent listings to 10' do
        15.times { create(:listing, tenant: tenant) }

        get :index
        expect(assigns(:recent_listings).count).to eq(10)
      end

      it 'orders recent listings by recent' do
        older_listing = create(:listing, tenant: tenant, created_at: 1.week.ago)
        newer_listing = create(:listing, tenant: tenant, created_at: 1.day.ago)

        get :index
        expect(assigns(:recent_listings).first).to eq(newer_listing)
      end

      it 'calculates correct stats' do
        create(:category, tenant: tenant)
        create(:listing, :published, tenant: tenant)
        create(:listing, :unpublished, tenant: tenant)
        create(:listing, :published, tenant: tenant, created_at: Time.current)

        get :index
        stats = assigns(:stats)

        expect(stats[:total_categories]).to eq(1)
        expect(stats[:total_listings]).to eq(2)
        expect(stats[:published_listings]).to eq(2)
        expect(stats[:listings_today]).to eq(1)
      end

      it 'sets correct meta tags' do
        get :index
        expect(response.body).to include(tenant.title)
      end
    end

    context 'when user is tenant owner' do
      before { sign_in owner_user }

      it 'returns http success' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'assigns all required instance variables' do
        get :index
        expect(assigns(:tenant)).to be_present
        expect(assigns(:categories)).to be_present
        expect(assigns(:recent_listings)).to be_present
        expect(assigns(:stats)).to be_present
      end
    end

    context 'when user is regular user' do
      before { sign_in regular_user }

      it 'raises authorization error' do
        expect { get :index }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when user is not signed in' do
      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'admin access control' do
    it 'includes AdminAccess concern' do
      expect(described_class.ancestors).to include(AdminAccess)
    end

    it 'requires admin access before all actions' do
      expect(described_class._process_action_callbacks.map(&:filter)).to include(:require_admin_access)
    end
  end

  describe 'tenant scoping' do
    let!(:other_tenant) { create(:tenant) }
    let!(:other_tenant_category) { create(:category, tenant: other_tenant) }
    let!(:other_tenant_listing) { create(:listing, tenant: other_tenant) }

    before { sign_in admin_user }

    it 'only shows data for current tenant' do
      get :index

      expect(assigns(:categories)).not_to include(other_tenant_category)
      expect(assigns(:recent_listings)).not_to include(other_tenant_listing)
    end
  end
end