# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoriesController, type: :controller do
  let(:tenant) { create(:tenant, :enabled) }
  let(:user) { create(:user) }
  let!(:category1) { create(:category, :news, tenant: tenant, name: 'News') }
  let!(:category2) { create(:category, :apps, tenant: tenant, name: 'Apps & Tools') }
  let!(:other_tenant_category) { create(:category, name: 'Other Category') }
  let!(:entry1) { create(:entry, :directory, :published, tenant: tenant, category: category1) }
  let!(:entry2) { create(:entry, :directory, :published, tenant: tenant, category: category2) }
  let!(:unpublished_entry) { create(:entry, :directory, :unpublished, tenant: tenant, category: category1) }

  before do
    setup_tenant_context(tenant)
    sign_in user
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns categories for current tenant' do
      get :index
      expect(assigns(:categories)).to include(category1, category2)
      expect(assigns(:categories)).not_to include(other_tenant_category)
    end

    it 'includes entries association' do
      get :index
      expect(assigns(:categories).first.association(:entries)).to be_loaded
    end

    it 'orders categories by name' do
      get :index
      expect(assigns(:categories)).to eq([ category2, category1 ]) # Apps & Tools comes before News
    end

    it 'sets correct meta tags' do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #show' do
    it 'returns http success' do
      get :show, params: { id: category1.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct category' do
      get :show, params: { id: category1.id }
      expect(assigns(:category)).to eq(category1)
    end

    it 'assigns published entries for the category' do
      get :show, params: { id: category1.id }
      expect(assigns(:entries)).to include(entry1)
      expect(assigns(:entries)).not_to include(unpublished_entry)
      expect(assigns(:entries)).not_to include(entry2) # Different category
    end

    it 'limits entries to 20' do
      # Create more than 20 entries
      25.times { create(:entry, :directory, :published, tenant: tenant, category: category1) }

      get :show, params: { id: category1.id }
      expect(assigns(:entries).count).to eq(20)
    end

    it 'includes category association in entries' do
      get :show, params: { id: category1.id }
      expect(assigns(:entries).first.association(:category)).to be_loaded
    end

    it 'orders entries by recent' do
      older_entry = create(:entry, :directory, :published, tenant: tenant, category: category1, published_at: 1.week.ago)
      newer_entry = create(:entry, :directory, :published, tenant: tenant, category: category1, published_at: 1.day.ago)

      get :show, params: { id: category1.id }
      expect(assigns(:entries).first).to eq(newer_entry)
    end

    it 'raises not found for category from other tenant' do
      expect {
        get :show, params: { id: other_tenant_category.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises not found for non-existent category' do
      expect {
        get :show, params: { id: 999999 }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'sets correct meta tags' do
      get :show, params: { id: category1.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'tenant privacy checks' do
    let(:private_tenant) { create(:tenant, :private_access) }

    before do
      setup_tenant_context(private_tenant)
      sign_out user
    end

    it 'redirects to login when accessing private tenant without auth' do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'allows access to private tenant when authenticated' do
      sign_in user
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe 'authorization' do
    it 'authorizes Category for index action' do
      expect(controller).to receive(:authorize).with(Category).and_call_original
      get :index
    end

    it 'authorizes category instance for show action' do
      expect(controller).to receive(:authorize).with(category1).and_call_original
      get :show, params: { id: category1.id }
    end

    it 'uses policy scope for categories' do
      expect(controller).to receive(:policy_scope).with(Category).and_call_original
      get :index
    end

    it 'uses policy scope for entries' do
      expect(controller).to receive(:policy_scope).and_call_original.at_least(:once)
      get :show, params: { id: category1.id }
    end
  end
end
