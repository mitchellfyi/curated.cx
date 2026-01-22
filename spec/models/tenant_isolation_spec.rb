# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Isolation for Categories and Listings', type: :model do
  let(:tenant1) { create(:tenant, slug: 'tenant1', hostname: 'tenant1.example.com') }
  let(:tenant2) { create(:tenant, slug: 'tenant2', hostname: 'tenant2.example.com') }
  let(:site1) { create(:site, tenant: tenant1) }
  let(:site2) { create(:site, tenant: tenant2) }

  describe 'listing uniqueness constraint' do
    it 'prevents duplicate canonical URLs within same site but allows across sites' do
      ActsAsTenant.without_tenant do
        # Create categories for each site
        category1 = create(:category, site: site1, tenant: tenant1, key: 'news', name: 'News')
        category2 = create(:category, site: site2, tenant: tenant2, key: 'news', name: 'News')

        url = 'https://example.com/article'

        # Create first listing in site1
        listing1 = create(:listing,
          site: site1,
          tenant: tenant1,
          category: category1,
          url_raw: url,
          title: 'Test Article 1'
        )

        expect(listing1).to be_persisted
        expect(listing1.url_canonical).to eq(url)

        # Attempt to create duplicate in same site should fail (validation or database constraint)
        expect {
          create(:listing,
            site: site1,
            tenant: tenant1,
            category: category1,
            url_raw: url,
            title: 'Test Article Duplicate'
          )
        }.to raise_error(ActiveRecord::RecordInvalid, /Url canonical has already been taken/)

        # Creating same URL in different site should succeed
        listing2 = create(:listing,
          site: site2,
          tenant: tenant2,
          category: category2,
          url_raw: url,
          title: 'Test Article 2'
        )

        expect(listing2).to be_persisted
        expect(listing2.url_canonical).to eq(url)
        expect(listing1.id).not_to eq(listing2.id)
      end
    end
  end

  describe 'category key uniqueness constraint' do
    it 'prevents duplicate category keys within same site but allows across sites' do
      ActsAsTenant.without_tenant do
        # Create first category in site1
        category1 = create(:category, site: site1, tenant: tenant1, key: 'news', name: 'News')

        expect(category1).to be_persisted

        # Attempt to create duplicate key in same site should fail
        expect {
          create(:category, site: site1, tenant: tenant1, key: 'news', name: 'Other News')
        }.to raise_error(ActiveRecord::RecordInvalid, /Key has already been taken/)

        # Creating same key in different site should succeed
        category2 = create(:category, site: site2, tenant: tenant2, key: 'news', name: 'News for Site 2')

        expect(category2).to be_persisted
        expect(category1.key).to eq(category2.key)
        expect(category1.id).not_to eq(category2.id)
      end
    end
  end
end
