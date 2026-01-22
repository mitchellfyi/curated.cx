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
        expect(flash[:alert]).to be_present
      end
    end

    context 'when user is not signed in' do
      it 'denies access and redirects to sign in' do
        get :test_action
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'Pundit integration' do
    it 'skips authorization verification' do
      # The concern uses skip_after_action which removes verify_authorized from callbacks
      callbacks = controller.class._process_action_callbacks.map(&:filter)
      expect(callbacks).not_to include(:verify_authorized)
    end

    it 'skips policy scoping verification' do
      # The concern uses skip_after_action which removes verify_policy_scoped from callbacks
      callbacks = controller.class._process_action_callbacks.map(&:filter)
      expect(callbacks).not_to include(:verify_policy_scoped)
    end
  end
end
