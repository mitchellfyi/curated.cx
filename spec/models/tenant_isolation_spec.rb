# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Isolation for Categories and Entries', type: :model do
  let(:tenant1) { create(:tenant, slug: 'tenant1', hostname: 'tenant1.example.com') }
  let(:tenant2) { create(:tenant, slug: 'tenant2', hostname: 'tenant2.example.com') }
  let(:site1) { create(:site, tenant: tenant1) }
  let(:site2) { create(:site, tenant: tenant2) }

  describe 'entry uniqueness constraint' do
    it 'prevents duplicate canonical URLs within same site but allows across sites' do
      ActsAsTenant.without_tenant do
        # Create categories for each site
        category1 = create(:category, site: site1, tenant: tenant1, key: 'news', name: 'News')
        category2 = create(:category, site: site2, tenant: tenant2, key: 'news', name: 'News')

        url = 'https://example.com/article'

        # Create first entry in site1
        entry1 = create(:entry, :directory,
          site: site1,
          tenant: tenant1,
          category: category1,
          url_raw: url,
          title: 'Test Article 1'
        )

        expect(entry1).to be_persisted
        expect(entry1.url_canonical).to eq(url)

        # Attempt to create duplicate in same site should fail (validation or database constraint)
        expect {
          create(:entry, :directory,
            site: site1,
            tenant: tenant1,
            category: category1,
            url_raw: url,
            title: 'Test Article Duplicate'
          )
        }.to raise_error(ActiveRecord::RecordInvalid, /Url canonical has already been taken/)

        # Creating same URL in different site should succeed
        entry2 = create(:entry, :directory,
          site: site2,
          tenant: tenant2,
          category: category2,
          url_raw: url,
          title: 'Test Article 2'
        )

        expect(entry2).to be_persisted
        expect(entry2.url_canonical).to eq(url)
        expect(entry1.id).not_to eq(entry2.id)
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
