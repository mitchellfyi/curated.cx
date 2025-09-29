# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant, :enabled) }
  let(:private_tenant) { create(:tenant, :private_access) }
  let(:disabled_tenant) { create(:tenant, :disabled) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe '#show?' do
    context 'when tenant is publicly accessible' do
      it 'allows access for any user' do
        policy = described_class.new(user, tenant)
        expect(policy.show?).to be true
      end

      it 'allows access for nil user' do
        policy = described_class.new(nil, tenant)
        expect(policy.show?).to be true
      end
    end

    context 'when tenant is private access' do
      it 'allows access for users with tenant roles' do
        user.add_role(:viewer, private_tenant)
        policy = described_class.new(user, private_tenant)
        expect(policy.show?).to be true
      end

      it 'denies access for users without tenant roles' do
        policy = described_class.new(user, private_tenant)
        expect(policy.show?).to be false
      end

      it 'denies access for nil user' do
        policy = described_class.new(nil, private_tenant)
        expect(policy.show?).to be false
      end
    end
  end

  describe '#about?' do
    context 'when tenant is publicly accessible' do
      it 'allows access for any user' do
        policy = described_class.new(user, tenant)
        expect(policy.about?).to be true
      end
    end

    context 'when tenant is private access' do
      it 'allows access for users with tenant roles' do
        user.add_role(:viewer, private_tenant)
        policy = described_class.new(user, private_tenant)
        expect(policy.about?).to be true
      end

      it 'denies access for users without tenant roles' do
        policy = described_class.new(user, private_tenant)
        expect(policy.about?).to be false
      end
    end
  end

  describe '#index?' do
    it 'allows access for admin users' do
      policy = described_class.new(admin_user, tenant)
      expect(policy.index?).to be true
    end

    it 'denies access for regular users' do
      policy = described_class.new(user, tenant)
      expect(policy.index?).to be false
    end

    it 'denies access for nil user' do
      policy = described_class.new(nil, tenant)
      expect(policy.index?).to be false
    end
  end

  describe '#create?' do
    it 'allows access for admin users' do
      policy = described_class.new(admin_user, tenant)
      expect(policy.create?).to be true
    end

    it 'denies access for regular users' do
      policy = described_class.new(user, tenant)
      expect(policy.create?).to be false
    end
  end

  describe '#update?' do
    it 'allows access for admin users' do
      policy = described_class.new(admin_user, tenant)
      expect(policy.update?).to be true
    end

    it 'denies access for regular users' do
      policy = described_class.new(user, tenant)
      expect(policy.update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows access for admin users' do
      policy = described_class.new(admin_user, tenant)
      expect(policy.destroy?).to be true
    end

    it 'denies access for regular users' do
      policy = described_class.new(user, tenant)
      expect(policy.destroy?).to be false
    end
  end

  describe 'Scope' do
    let(:scope) { Tenant.all }
    let(:policy_scope) { described_class::Scope.new(user, scope) }

    context 'when user is admin' do
      let(:user) { admin_user }

      it 'returns all tenants' do
        expect(policy_scope.resolve).to include(tenant, private_tenant, disabled_tenant)
      end
    end

    context 'when user is not admin' do
      it 'returns only publicly accessible tenants' do
        result = policy_scope.resolve
        expect(result).to include(tenant, private_tenant)
        expect(result).not_to include(disabled_tenant)
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns only publicly accessible tenants' do
        result = policy_scope.resolve
        expect(result).to include(tenant, private_tenant)
        expect(result).not_to include(disabled_tenant)
      end
    end
  end
end
