# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantScoped, type: :model do
  # Create a test model that includes the concern
  let(:test_model_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'listings' # Use existing table for testing
      include TenantScoped
    end
  end

  let(:tenant1) { create(:tenant) }
  let(:tenant2) { create(:tenant) }

  before do
    # Set up test data
    Current.tenant = tenant1
    @record1 = test_model_class.create!(tenant: tenant1, url_raw: 'https://example1.com', url_canonical: 'https://example1.com', title: 'Test 1')
    @record2 = test_model_class.create!(tenant: tenant2, url_raw: 'https://example2.com', url_canonical: 'https://example2.com', title: 'Test 2')
  end

  after do
    Current.reset
  end

  describe 'tenant scoping' do
    it 'scopes queries to current tenant by default' do
      records = test_model_class.all
      expect(records).to include(@record1)
      expect(records).not_to include(@record2)
    end

    it 'changes scope when Current.tenant changes' do
      Current.tenant = tenant2
      records = test_model_class.all
      expect(records).to include(@record2)
      expect(records).not_to include(@record1)
    end

    it 'returns empty scope when Current.tenant is nil' do
      Current.tenant = nil
      records = test_model_class.all
      expect(records).to be_empty
    end
  end

  describe 'without_tenant_scope' do
    it 'returns all records regardless of tenant' do
      records = test_model_class.without_tenant_scope
      expect(records).to include(@record1, @record2)
    end
  end

  describe 'for_tenant' do
    it 'returns records for specific tenant' do
      records = test_model_class.for_tenant(tenant1)
      expect(records).to include(@record1)
      expect(records).not_to include(@record2)
    end

    it 'returns records for different tenant' do
      records = test_model_class.for_tenant(tenant2)
      expect(records).to include(@record2)
      expect(records).not_to include(@record1)
    end
  end

  describe 'require_tenant!' do
    it 'raises error when Current.tenant is nil' do
      Current.tenant = nil
      expect {
        test_model_class.require_tenant!
      }.to raise_error("Current.tenant must be set to perform this operation")
    end

    it 'does not raise error when Current.tenant is set' do
      Current.tenant = tenant1
      expect {
        test_model_class.require_tenant!
      }.not_to raise_error
    end
  end

  describe 'acts_as_tenant_tenant' do
    it 'returns Current.tenant' do
      Current.tenant = tenant1
      expect(test_model_class.acts_as_tenant_tenant).to eq(tenant1)
    end
  end

  describe 'ensure_tenant_consistency!' do
    it 'raises error when record belongs to different tenant' do
      Current.tenant = tenant2
      expect {
        @record1.ensure_tenant_consistency!
      }.to raise_error("Record belongs to different tenant than Current.tenant")
    end

    it 'does not raise error when record belongs to current tenant' do
      Current.tenant = tenant1
      expect {
        @record1.ensure_tenant_consistency!
      }.not_to raise_error
    end

    it 'does not raise error when Current.tenant is nil' do
      Current.tenant = nil
      expect {
        @record1.ensure_tenant_consistency!
      }.not_to raise_error
    end
  end

  describe 'jsonb_field' do
    let(:record) { test_model_class.create!(tenant: tenant1, url_raw: 'https://example.com', url_canonical: 'https://example.com', title: 'Test', ai_summaries: { short: 'Summary' }) }

    it 'returns the field value when present' do
      expect(record.jsonb_field(:ai_summaries)).to eq({ 'short' => 'Summary' })
    end

    it 'returns empty hash when field is nil' do
      record.update!(ai_summaries: nil)
      expect(record.jsonb_field(:ai_summaries)).to eq({})
    end
  end

  describe 'validations' do
    it 'validates tenant presence' do
      record = test_model_class.new(url_raw: 'https://example.com', url_canonical: 'https://example.com', title: 'Test')
      expect(record).not_to be_valid
      expect(record.errors[:tenant]).to include("must exist")
    end
  end
end
