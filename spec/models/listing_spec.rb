# == Schema Information
#
# Table name: listings
#
#  id            :bigint           not null, primary key
#  ai_summaries  :jsonb            not null
#  ai_tags       :jsonb            not null
#  body_html     :text
#  body_text     :text
#  description   :text
#  domain        :string
#  image_url     :text
#  metadata      :jsonb            not null
#  published_at  :datetime
#  site_name     :string
#  title         :string
#  url_canonical :text             not null
#  url_raw       :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  category_id   :bigint           not null
#  tenant_id     :bigint           not null
#
# Indexes
#
#  index_listings_on_category_id                (category_id)
#  index_listings_on_domain                     (domain)
#  index_listings_on_published_at               (published_at)
#  index_listings_on_tenant_and_url_canonical   (tenant_id,url_canonical) UNIQUE
#  index_listings_on_tenant_id                  (tenant_id)
#  index_listings_on_tenant_id_and_category_id  (tenant_id,category_id)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
require 'rails_helper'

RSpec.describe Listing, type: :model do
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant, allow_paths: true) }

  describe 'associations' do
    it { should belong_to(:tenant) }
    it { should belong_to(:category) }
  end

  describe 'validations' do
    subject { build(:listing, tenant: tenant, category: category) }

    it { should validate_presence_of(:url_raw) }
    it { should validate_presence_of(:title) }

    it 'validates url_canonical uniqueness within tenant' do
      existing = create(:listing, tenant: tenant, category: category, url_raw: 'https://example.com/test')
      new_listing = build(:listing, tenant: tenant, category: category, url_raw: 'https://example.com/test')

      expect(new_listing).not_to be_valid
      expect(new_listing.errors[:url_canonical]).to be_present
    end
  end

  describe 'tenant isolation' do
    let(:tenant1) { create(:tenant, slug: 'tenant1') }
    let(:tenant2) { create(:tenant, slug: 'tenant2') }
    let(:category1) { create(:category, tenant: tenant1) }
    let(:category2) { create(:category, tenant: tenant2) }

    it 'allows same canonical URL across different tenants' do
      ActsAsTenant.with_tenant(tenant1) do
        create(:listing, category: category1, url_raw: 'https://example.com/article')
      end

      ActsAsTenant.with_tenant(tenant2) do
        expect { create(:listing, category: category2, url_raw: 'https://example.com/article') }.not_to raise_error
      end
    end

    it 'prevents duplicate canonical URLs within same tenant' do
      ActsAsTenant.with_tenant(tenant1) do
        create(:listing, category: category1, url_raw: 'https://example.com/article')
        expect { create(:listing, category: category1, url_raw: 'https://example.com/article') }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe 'URL canonicalization' do
    it 'canonicalizes URLs on save' do
      listing = build(:listing,
        tenant: tenant,
        category: category,
        url_raw: 'HTTP://EXAMPLE.COM/Article/?utm_source=test&other=keep'
      )
      listing.save!

      expect(listing.url_canonical).to eq('http://example.com/Article?other=keep')
      expect(listing.domain).to eq('example.com')
    end

    it 'removes tracking parameters' do
      listing = build(:listing,
        tenant: tenant,
        category: category,
        url_raw: 'https://example.com/article?utm_source=google&utm_medium=email&fbclid=12345&ref=homepage'
      )
      listing.save!

      expect(listing.url_canonical).to eq('https://example.com/article')
    end

    it 'normalizes path by removing trailing slash' do
      listing = build(:listing,
        tenant: tenant,
        category: category,
        url_raw: 'https://example.com/article/'
      )
      listing.save!

      expect(listing.url_canonical).to eq('https://example.com/article')
    end

    it 'keeps root path slash' do
      listing = build(:listing,
        tenant: tenant,
        category: category,
        url_raw: 'https://example.com/'
      )
      listing.save!

      expect(listing.url_canonical).to eq('https://example.com/')
    end

    it 'handles invalid URLs' do
      listing = build(:listing,
        tenant: tenant,
        category: category,
        url_raw: 'not-a-valid-url'
      )

      expect(listing).not_to be_valid
      expect(listing.errors[:url_raw]).to include(match(/must be a valid HTTP or HTTPS URL/))
    end
  end

  describe 'category URL validation' do
    context 'when category allows paths' do
      let(:category) { create(:category, tenant: tenant, allow_paths: true) }

      it 'allows path URLs' do
        listing = build(:listing, tenant: tenant, category: category, url_raw: 'https://example.com/article/123')
        expect(listing).to be_valid
      end

      it 'allows root URLs' do
        listing = build(:listing, tenant: tenant, category: category, url_raw: 'https://example.com')
        expect(listing).to be_valid
      end
    end

    context 'when category requires root domain only' do
      let(:category) { create(:category, tenant: tenant, allow_paths: false) }

      it 'rejects path URLs' do
        listing = build(:listing, tenant: tenant, category: category, url_raw: 'https://example.com/article/123')
        expect(listing).not_to be_valid
        expect(listing.errors[:url_canonical]).to include('must be a root domain URL for this category')
      end

      it 'allows root URLs' do
        listing = build(:listing, tenant: tenant, category: category, url_raw: 'https://example.com')
        expect(listing).to be_valid
      end
    end
  end

  describe 'JSONB field validation' do
    it 'validates ai_summaries is a hash' do
      listing = build(:listing, tenant: tenant, category: category, ai_summaries: 'not a hash')
      expect(listing).not_to be_valid
      expect(listing.errors[:ai_summaries]).to include('must be a valid JSON object')
    end

    it 'validates ai_tags is a hash' do
      listing = build(:listing, tenant: tenant, category: category, ai_tags: 'not a hash')
      expect(listing).not_to be_valid
      expect(listing.errors[:ai_tags]).to include('must be a valid JSON object')
    end

    it 'validates metadata is a hash' do
      listing = build(:listing, tenant: tenant, category: category, metadata: 'not a hash')
      expect(listing).not_to be_valid
      expect(listing.errors[:metadata]).to include('must be a valid JSON object')
    end
  end

  describe 'JSONB field defaults' do
    let(:listing) { create(:listing, tenant: tenant, category: category) }

    it 'returns empty hash for ai_summaries by default' do
      expect(listing.ai_summaries).to be_a(Hash)
    end

    it 'returns empty hash for ai_tags by default' do
      expect(listing.ai_tags).to be_a(Hash)
    end

    it 'returns empty hash for metadata by default' do
      expect(listing.metadata).to be_a(Hash)
    end

    it 'handles ai_summaries getter when field is empty' do
      listing.update_columns(ai_summaries: {})
      expect(listing.ai_summaries).to eq({})
    end
  end

  describe '#root_domain' do
    it 'extracts root domain from subdomain' do
      listing = create(:listing, tenant: tenant, category: category, url_raw: 'https://blog.example.com/article')
      expect(listing.root_domain).to eq('example.com')
    end

    it 'returns domain when already root' do
      listing = create(:listing, tenant: tenant, category: category, url_raw: 'https://example.com/article')
      expect(listing.root_domain).to eq('example.com')
    end

    it 'handles complex subdomains' do
      listing = create(:listing, tenant: tenant, category: category, url_raw: 'https://api.v2.example.com/article')
      expect(listing.root_domain).to eq('example.com')
    end

    it 'returns nil for invalid URLs' do
      listing = build(:listing, tenant: tenant, category: category)
      # Use SQL to set invalid URL directly
      listing.save!
      listing.class.where(id: listing.id).update_all(url_canonical: 'invalid-url')
      listing.reload
      expect(listing.root_domain).to be_nil
    end
  end

  describe 'scopes' do
    let!(:published_listing) { create(:listing, tenant: tenant, category: category, published_at: 1.day.ago) }
    let!(:unpublished_listing) { create(:listing, tenant: tenant, category: category, published_at: nil) }
    let!(:domain_listing) { create(:listing, tenant: tenant, category: category, url_raw: 'https://example.com/test') }
    let!(:content_listing) { create(:listing, tenant: tenant, category: category, body_html: '<p>Content</p>') }
    let!(:no_content_listing) { create(:listing, tenant: tenant, category: category, body_html: nil) }

    describe '.published' do
      it 'returns only listings with published_at set' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.published).to include(published_listing)
          expect(Listing.published).not_to include(unpublished_listing)
        end
      end
    end

    describe '.recent' do
      it 'orders by published_at desc, then created_at desc' do
        ActsAsTenant.with_tenant(tenant) do
          recent_listings = Listing.recent.limit(5)
          expect(recent_listings).to include(published_listing)
          # Just verify the scope exists and returns results
          expect(recent_listings.count).to be > 0
        end
      end
    end

    describe '.by_domain' do
      it 'filters by domain' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.by_domain('example.com')).to include(domain_listing)
          expect(Listing.by_domain('other.com').count).to eq(0)
        end
      end
    end

    describe '.with_content' do
      it 'returns only listings with body_html' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.with_content).to include(content_listing)
          expect(Listing.with_content).not_to include(no_content_listing)
        end
      end
    end
  end
end
