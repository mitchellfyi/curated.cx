# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::ListingsService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant) }
  let(:service) { described_class.new(tenant) }

  describe '#initialize' do
    it 'sets the tenant' do
      expect(service.instance_variable_get(:@tenant)).to eq(tenant)
    end
  end

  describe '#all_listings' do
    let!(:listing1) { create(:listing, tenant: tenant, category: category) }
    let!(:listing2) { create(:listing, tenant: tenant, category: category) }
    let!(:other_tenant_listing) { create(:listing) }

    it 'returns listings for the current tenant' do
      listings = service.all_listings
      expect(listings).to include(listing1, listing2)
      expect(listings).not_to include(other_tenant_listing)
    end

    it 'includes category association' do
      listings = service.all_listings
      expect(listings.first.association(:category)).to be_loaded
    end

    it 'orders by recent' do
      listings = service.all_listings
      expect(listings.first).to eq(listing2) # Most recent first
    end

    context 'with category filter' do
      let(:other_category) { create(:category, tenant: tenant) }
      let!(:other_category_listing) { create(:listing, tenant: tenant, category: other_category) }

      it 'filters by category_id' do
        listings = service.all_listings(category_id: category.id)
        expect(listings).to include(listing1, listing2)
        expect(listings).not_to include(other_category_listing)
      end
    end

    context 'with limit' do
      it 'limits the number of results' do
        listings = service.all_listings(limit: 1)
        expect(listings.count).to eq(1)
      end
    end
  end

  describe '#find_listing' do
    let!(:listing) { create(:listing, tenant: tenant) }

    it 'finds the listing by id' do
      found_listing = service.find_listing(listing.id)
      expect(found_listing).to eq(listing)
    end

    it 'raises error for non-existent listing' do
      expect {
        service.find_listing(99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#create_listing' do
    let(:attributes) do
      {
        category_id: category.id,
        url_raw: 'https://example.com',
        title: 'Test Listing',
        description: 'Test description'
      }
    end

    it 'creates a new listing with given attributes' do
      listing = service.create_listing(attributes)
      expect(listing).to be_a(Listing)
      expect(listing.category_id).to eq(category.id)
      expect(listing.url_raw).to eq('https://example.com')
      expect(listing.title).to eq('Test Listing')
      expect(listing.description).to eq('Test description')
    end

    it 'does not save the listing' do
      expect {
        service.create_listing(attributes)
      }.not_to change(Listing, :count)
    end
  end

  describe '#update_listing' do
    let!(:listing) { create(:listing, tenant: tenant, title: 'Original Title') }

    it 'updates the listing with new attributes' do
      result = service.update_listing(listing, { title: 'Updated Title' })
      expect(result).to be true
      expect(listing.reload.title).to eq('Updated Title')
    end

    it 'returns false for invalid attributes' do
      result = service.update_listing(listing, { title: '' })
      expect(result).to be false
      expect(listing.reload.title).to eq('Original Title')
    end
  end

  describe '#destroy_listing' do
    let!(:listing) { create(:listing, tenant: tenant) }

    it 'destroys the listing' do
      expect {
        service.destroy_listing(listing)
      }.to change(Listing, :count).by(-1)
    end

    it 'returns the destroyed listing' do
      result = service.destroy_listing(listing)
      expect(result).to eq(listing)
    end
  end
end
