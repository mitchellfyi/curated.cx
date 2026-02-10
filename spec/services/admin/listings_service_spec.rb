# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::EntriesService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant) }
  let(:service) { described_class.new(tenant) }

  describe '#initialize' do
    it 'sets the tenant' do
      expect(service.instance_variable_get(:@tenant)).to eq(tenant)
    end
  end

  describe '#all_entries' do
    let!(:entry1) { create(:entry, :directory, tenant: tenant, category: category) }
    let!(:entry2) { create(:entry, :directory, tenant: tenant, category: category) }
    let!(:other_tenant_entry) { create(:entry, :directory) }

    it 'returns entries for the current tenant' do
      entries = service.all_entries
      expect(entries).to include(entry1, entry2)
      expect(entries).not_to include(other_tenant_entry)
    end

    it 'includes category association' do
      entries = service.all_entries
      expect(entries.first.association(:category)).to be_loaded
    end

    it 'orders by recent' do
      entries = service.all_entries
      expect(entries.first).to eq(entry2) # Most recent first
    end

    context 'with category filter' do
      let(:other_category) { create(:category, tenant: tenant) }
      let!(:other_category_entry) { create(:entry, :directory, tenant: tenant, category: other_category) }

      it 'filters by category_id' do
        entries = service.all_entries(category_id: category.id)
        expect(entries).to include(entry1, entry2)
        expect(entries).not_to include(other_category_entry)
      end
    end

    context 'with limit' do
      it 'limits the number of results' do
        entries = service.all_entries(limit: 1)
        expect(entries.count).to eq(1)
      end
    end
  end

  describe '#find_entry' do
    let!(:entry) { create(:entry, :directory, tenant: tenant) }

    it 'finds the entry by id' do
      found_entry = service.find_entry(entry.id)
      expect(found_entry).to eq(entry)
    end

    it 'raises error for non-existent entry' do
      expect {
        service.find_entry(99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#create_entry' do
    let(:attributes) do
      {
        category_id: category.id,
        url_raw: 'https://example.com',
        title: 'Test Entry',
        description: 'Test description'
      }
    end

    it 'creates a new entry with given attributes' do
      entry = service.create_entry(attributes)
      expect(entry).to be_a(Entry)
      expect(entry.category_id).to eq(category.id)
      expect(entry.url_raw).to eq('https://example.com')
      expect(entry.title).to eq('Test Entry')
      expect(entry.description).to eq('Test description')
    end

    it 'does not save the entry' do
      expect {
        service.create_entry(attributes)
      }.not_to change(Entry, :count)
    end
  end

  describe '#update_entry' do
    let!(:entry) { create(:entry, :directory, tenant: tenant, title: 'Original Title') }

    it 'updates the entry with new attributes' do
      result = service.update_entry(entry, { title: 'Updated Title' })
      expect(result).to be true
      expect(entry.reload.title).to eq('Updated Title')
    end

    it 'returns false for invalid attributes' do
      result = service.update_entry(entry, { title: '' })
      expect(result).to be false
      expect(entry.reload.title).to eq('Original Title')
    end
  end

  describe '#destroy_entry' do
    let!(:entry) { create(:entry, :directory, tenant: tenant) }

    it 'destroys the entry' do
      expect {
        service.destroy_entry(entry)
      }.to change(Entry, :count).by(-1)
    end

    it 'returns the destroyed entry' do
      result = service.destroy_entry(entry)
      expect(result).to eq(entry)
    end
  end
end
