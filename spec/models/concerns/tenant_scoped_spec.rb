# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantScoped, type: :model do
  # Test using Category model which includes TenantScoped
  let(:tenant1) { create(:tenant) }
  let(:tenant2) { create(:tenant) }
  let(:site1) { create(:site, tenant: tenant1) }
  let(:site2) { create(:site, tenant: tenant2) }

  # Create records outside of tenant context to avoid acts_as_tenant interference
  let!(:record1) do
    ActsAsTenant.without_tenant do
      create(:category, tenant: tenant1, site: site1, key: 'test1', name: 'Test 1')
    end
  end

  let!(:record2) do
    ActsAsTenant.without_tenant do
      create(:category, tenant: tenant2, site: site2, key: 'test2', name: 'Test 2')
    end
  end

  after do
    Current.reset
    ActsAsTenant.current_tenant = nil
  end

  describe 'tenant scoping' do
    it 'validates tenant presence' do
      ActsAsTenant.without_tenant do
        # Category without site or tenant should fail validation
        record = Category.new(key: 'new_cat', name: 'New Category')
        expect(record).not_to be_valid
        expect(record.errors[:tenant]).to include("must exist")
      end
    end
  end

  describe 'without_tenant_scope' do
    it 'returns all records regardless of tenant' do
      records = Category.without_tenant_scope
      expect(records).to include(record1, record2)
    end
  end

  describe 'for_tenant' do
    it 'returns records for specific tenant' do
      records = Category.for_tenant(tenant1)
      expect(records).to include(record1)
      expect(records).not_to include(record2)
    end

    it 'returns records for different tenant' do
      records = Category.for_tenant(tenant2)
      expect(records).to include(record2)
      expect(records).not_to include(record1)
    end
  end

  describe 'require_tenant!' do
    it 'raises error when Current.tenant is nil' do
      Current.reset
      ActsAsTenant.current_tenant = nil
      expect {
        Category.require_tenant!
      }.to raise_error("Current.tenant must be set to perform this operation")
    end

    it 'does not raise error when Current.tenant is set' do
      setup_tenant_context(tenant1)
      expect {
        Category.require_tenant!
      }.not_to raise_error
    end
  end

  describe 'acts_as_tenant_tenant' do
    it 'returns Current.tenant' do
      setup_tenant_context(tenant1)
      expect(Category.acts_as_tenant_tenant).to eq(tenant1)
    end
  end

  describe 'ensure_tenant_consistency!' do
    it 'raises error when record belongs to different tenant' do
      setup_tenant_context(tenant2)
      expect {
        record1.ensure_tenant_consistency!
      }.to raise_error("Record belongs to different tenant than Current.tenant")
    end

    it 'does not raise error when record belongs to current tenant' do
      setup_tenant_context(tenant1)
      expect {
        record1.ensure_tenant_consistency!
      }.not_to raise_error
    end

    it 'does not raise error when Current.tenant is nil' do
      Current.reset
      ActsAsTenant.current_tenant = nil
      expect {
        record1.ensure_tenant_consistency!
      }.not_to raise_error
    end
  end
end
