# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminAccess, type: :controller do
  # Create a test controller that includes the concern
  controller(ApplicationController) do
    include AdminAccess

    def test_action
      render plain: 'success'
    end
  end

  before do
    routes.draw do
      get 'test_action' => 'anonymous#test_action'
    end
  end

  let(:tenant) { create(:tenant) }
  let(:admin_user) { create(:user, admin: true) }
  let(:owner_user) { create(:user) }
  let(:regular_user) { create(:user) }

  before do
    setup_tenant_context(tenant)
    owner_user.add_role(:owner, tenant)
  end

  describe 'admin access control' do
    context 'when user is admin' do
      before { sign_in admin_user }

      it 'allows access' do
        get :test_action
        expect(response).to have_http_status(:success)
        expect(response.body).to eq('success')
      end
    end

    context 'when user is tenant owner' do
      before { sign_in owner_user }

      it 'allows access' do
        get :test_action
        expect(response).to have_http_status(:success)
        expect(response.body).to eq('success')
      end
    end

    context 'when user is regular user' do
      before { sign_in regular_user }

      it 'denies access and redirects' do
        get :test_action
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
      end
    end

    context 'when user is not signed in' do
      it 'denies access and redirects' do
        get :test_action
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
      end
    end
  end

  describe 'Pundit integration' do
    it 'skips authorization verification' do
      expect(controller.class._process_action_callbacks.map(&:filter)).to include(:verify_authorized)
      expect(controller.class._process_action_callbacks.select { |c| c.filter == :verify_authorized }.first.options[:if]).to be_present
    end

    it 'skips policy scoping verification' do
      expect(controller.class._process_action_callbacks.map(&:filter)).to include(:verify_policy_scoped)
      expect(controller.class._process_action_callbacks.select { |c| c.filter == :verify_policy_scoped }.first.options[:if]).to be_present
    end
  end
end
