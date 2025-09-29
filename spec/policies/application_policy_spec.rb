# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:tenant) { create(:tenant) }
  let(:record) { double('record') }
  let(:policy) { described_class.new(user, record) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe '#index?' do
    it 'returns true when user is present' do
      expect(policy.index?).to be true
    end

    it 'returns false when user is nil' do
      policy = described_class.new(nil, record)
      expect(policy.index?).to be false
    end
  end

  describe '#show?' do
    it 'returns true when user is present' do
      expect(policy.show?).to be true
    end

    it 'returns false when user is nil' do
      policy = described_class.new(nil, record)
      expect(policy.show?).to be false
    end
  end

  describe '#create?' do
    context 'when user is admin' do
      let(:user) { create(:user, admin: true) }

      it 'returns true' do
        expect(policy.create?).to be true
      end
    end

    context 'when user has editor role' do
      before { user.add_role(:editor, tenant) }

      it 'returns true' do
        expect(policy.create?).to be true
      end
    end

    context 'when user has admin role' do
      before { user.add_role(:admin, tenant) }

      it 'returns true' do
        expect(policy.create?).to be true
      end
    end

    context 'when user has owner role' do
      before { user.add_role(:owner, tenant) }

      it 'returns true' do
        expect(policy.create?).to be true
      end
    end

    context 'when user has viewer role' do
      before { user.add_role(:viewer, tenant) }

      it 'returns false' do
        expect(policy.create?).to be false
      end
    end

    context 'when user has no roles' do
      it 'returns false' do
        expect(policy.create?).to be false
      end
    end

    context 'when user is nil' do
      let(:policy) { described_class.new(nil, record) }

      it 'returns false' do
        expect(policy.create?).to be false
      end
    end

    context 'when Current.tenant is nil' do
      before { allow(Current).to receive(:tenant).and_return(nil) }

      it 'returns false' do
        expect(policy.create?).to be false
      end
    end
  end

  describe '#update?' do
    it 'delegates to create?' do
      expect(policy).to receive(:create?).and_return(true)
      expect(policy.update?).to be true
    end
  end

  describe '#destroy?' do
    context 'when user is admin' do
      let(:user) { create(:user, admin: true) }

      it 'returns true' do
        expect(policy.destroy?).to be true
      end
    end

    context 'when user has admin role' do
      before { user.add_role(:admin, tenant) }

      it 'returns true' do
        expect(policy.destroy?).to be true
      end
    end

    context 'when user has owner role' do
      before { user.add_role(:owner, tenant) }

      it 'returns true' do
        expect(policy.destroy?).to be true
      end
    end

    context 'when user has editor role' do
      before { user.add_role(:editor, tenant) }

      it 'returns false' do
        expect(policy.destroy?).to be false
      end
    end

    context 'when user has viewer role' do
      before { user.add_role(:viewer, tenant) }

      it 'returns false' do
        expect(policy.destroy?).to be false
      end
    end
  end

  describe 'Scope' do
    let(:scope) { double('scope', model: Listing) }
    let(:policy_scope) { described_class::Scope.new(user, scope) }

    context 'when user is admin' do
      let(:user) { create(:user, admin: true) }

      it 'returns all records' do
        expect(scope).to receive(:all)
        policy_scope.resolve
      end
    end

    context 'when Current.tenant is present' do
      it 'filters by tenant_id' do
        expect(scope).to receive(:where).with(tenant_id: tenant.id)
        policy_scope.resolve
      end
    end

    context 'when Current.tenant is nil' do
      before { allow(Current).to receive(:tenant).and_return(nil) }

      it 'returns no records' do
        expect(scope).to receive(:none)
        policy_scope.resolve
      end
    end
  end
end
