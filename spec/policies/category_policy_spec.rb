# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoryPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe '#index?' do
    it 'allows access for any user' do
      policy = described_class.new(user, category)
      expect(policy.index?).to be true
    end

    it 'allows access for nil user' do
      policy = described_class.new(nil, category)
      expect(policy.index?).to be true
    end
  end

  describe '#show?' do
    it 'allows access for any user' do
      policy = described_class.new(user, category)
      expect(policy.show?).to be true
    end

    it 'allows access for nil user' do
      policy = described_class.new(nil, category)
      expect(policy.show?).to be true
    end
  end

  describe '#create?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = described_class.new(admin_user, category)
        expect(policy.create?).to be true
      end
    end

    context 'when user has editor role' do
      before { user.add_role(:editor, tenant) }

      it 'allows access' do
        policy = described_class.new(user, category)
        expect(policy.create?).to be true
      end
    end

    context 'when user has admin role' do
      before { user.add_role(:admin, tenant) }

      it 'allows access' do
        policy = described_class.new(user, category)
        expect(policy.create?).to be true
      end
    end

    context 'when user has owner role' do
      before { user.add_role(:owner, tenant) }

      it 'allows access' do
        policy = described_class.new(user, category)
        expect(policy.create?).to be true
      end
    end

    context 'when user has viewer role' do
      before { user.add_role(:viewer, tenant) }

      it 'denies access' do
        policy = described_class.new(user, category)
        expect(policy.create?).to be false
      end
    end

    context 'when user has no roles' do
      it 'denies access' do
        policy = described_class.new(user, category)
        expect(policy.create?).to be false
      end
    end

    context 'when user is nil' do
      it 'denies access' do
        policy = described_class.new(nil, category)
        expect(policy.create?).to be false
      end
    end
  end

  describe '#update?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = described_class.new(admin_user, category)
        expect(policy.update?).to be true
      end
    end

    context 'when user has editor role' do
      before { user.add_role(:editor, tenant) }

      it 'allows access' do
        policy = described_class.new(user, category)
        expect(policy.update?).to be true
      end
    end

    context 'when user has viewer role' do
      before { user.add_role(:viewer, tenant) }

      it 'denies access' do
        policy = described_class.new(user, category)
        expect(policy.update?).to be false
      end
    end
  end

  describe '#destroy?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = described_class.new(admin_user, category)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user has admin role' do
      before { user.add_role(:admin, tenant) }

      it 'allows access' do
        policy = described_class.new(user, category)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user has owner role' do
      before { user.add_role(:owner, tenant) }

      it 'allows access' do
        policy = described_class.new(user, category)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user has editor role' do
      before { user.add_role(:editor, tenant) }

      it 'denies access' do
        policy = described_class.new(user, category)
        expect(policy.destroy?).to be false
      end
    end

    context 'when user has viewer role' do
      before { user.add_role(:viewer, tenant) }

      it 'denies access' do
        policy = described_class.new(user, category)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe 'Scope' do
    let(:scope) { Category.all }
    let(:policy_scope) { described_class::Scope.new(user, scope) }

    context 'when user is admin' do
      let(:user) { admin_user }

      it 'returns all categories' do
        expect(policy_scope.resolve).to include(category)
      end
    end

    context 'when Current.tenant is present' do
      it 'filters by tenant_id' do
        other_tenant = create(:tenant)
        other_category = create(:category, tenant: other_tenant)

        result = policy_scope.resolve
        expect(result).to include(category)
        expect(result).not_to include(other_category)
      end
    end

    context 'when Current.tenant is nil' do
      before { allow(Current).to receive(:tenant).and_return(nil) }

      it 'returns no categories' do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
