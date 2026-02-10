# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::CategoriesService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:service) { described_class.new(tenant) }

  describe '#initialize' do
    it 'sets the tenant' do
      expect(service.instance_variable_get(:@tenant)).to eq(tenant)
    end
  end

  describe '#all_categories' do
    let!(:category1) { create(:category, tenant: tenant, name: 'Category A') }
    let!(:category2) { create(:category, tenant: tenant, name: 'Category B') }
    let!(:other_tenant_category) { create(:category) }

    it 'returns categories for the current tenant' do
      categories = service.all_categories
      expect(categories).to include(category1, category2)
      expect(categories).not_to include(other_tenant_category)
    end

    it 'includes entries association' do
      categories = service.all_categories
      expect(categories.first.association(:entries)).to be_loaded
    end

    it 'orders by name' do
      categories = service.all_categories
      expect(categories.first).to eq(category1) # Alphabetical order
      expect(categories.last).to eq(category2)
    end
  end

  describe '#find_category' do
    let!(:category) { create(:category, tenant: tenant) }

    it 'finds the category by id' do
      found_category = service.find_category(category.id)
      expect(found_category).to eq(category)
    end

    it 'raises error for non-existent category' do
      expect {
        service.find_category(99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
