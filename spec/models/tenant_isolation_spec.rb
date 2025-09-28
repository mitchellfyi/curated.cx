# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tenant Isolation for Categories and Listings', type: :model do
  let(:tenant1) { create(:tenant, slug: 'tenant1', hostname: 'tenant1.example.com') }
  let(:tenant2) { create(:tenant, slug: 'tenant2', hostname: 'tenant2.example.com') }

  describe 'listing uniqueness constraint' do
    it 'prevents duplicate canonical URLs within same tenant but allows across tenants' do
      # Create categories for each tenant
      category1 = nil
      category2 = nil
      
      ActsAsTenant.with_tenant(tenant1) do
        category1 = create(:category, key: 'news', name: 'News')
      end

      ActsAsTenant.with_tenant(tenant2) do
        category2 = create(:category, key: 'news', name: 'News')
      end

      url = 'https://example.com/article'

      # Create first listing in tenant1
      listing1 = nil
      ActsAsTenant.with_tenant(tenant1) do
        listing1 = create(:listing, 
          category: category1, 
          url_raw: url, 
          title: 'Test Article 1'
        )
      end

      expect(listing1).to be_persisted
      expect(listing1.url_canonical).to eq(url)

      # Attempt to create duplicate in same tenant should fail
      ActsAsTenant.with_tenant(tenant1) do
        expect {
          create(:listing, 
            category: category1, 
            url_raw: url, 
            title: 'Test Article Duplicate'
          )
        }.to raise_error(ActiveRecord::RecordInvalid, /Url canonical has already been taken/)
      end

      # Creating same URL in different tenant should succeed
      listing2 = nil
      ActsAsTenant.with_tenant(tenant2) do
        listing2 = create(:listing, 
          category: category2, 
          url_raw: url, 
          title: 'Test Article 2'
        )
      end

      expect(listing2).to be_persisted
      expect(listing2.url_canonical).to eq(url)
      expect(listing1.id).not_to eq(listing2.id)
    end
  end

  describe 'category key uniqueness constraint' do
    it 'prevents duplicate category keys within same tenant but allows across tenants' do
      # Create first category in tenant1
      category1 = nil
      ActsAsTenant.with_tenant(tenant1) do
        category1 = create(:category, key: 'news', name: 'News')
      end

      expect(category1).to be_persisted

      # Attempt to create duplicate key in same tenant should fail
      ActsAsTenant.with_tenant(tenant1) do
        expect {
          create(:category, key: 'news', name: 'Other News')
        }.to raise_error(ActiveRecord::RecordInvalid, /Key has already been taken/)
      end

      # Creating same key in different tenant should succeed
      category2 = nil
      ActsAsTenant.with_tenant(tenant2) do
        category2 = create(:category, key: 'news', name: 'News for Tenant 2')
      end

      expect(category2).to be_persisted
      expect(category1.key).to eq(category2.key)
      expect(category1.id).not_to eq(category2.id)
    end
  end
end