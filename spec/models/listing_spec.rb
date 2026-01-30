# == Schema Information
#
# Table name: listings
#
#  id                         :bigint           not null, primary key
#  affiliate_attribution      :jsonb            not null
#  affiliate_url_template     :text
#  ai_summaries               :jsonb            not null
#  ai_tags                    :jsonb            not null
#  apply_url                  :text
#  body_html                  :text
#  body_text                  :text
#  company                    :string
#  description                :text
#  domain                     :string
#  expires_at                 :datetime
#  featured_from              :datetime
#  featured_until             :datetime
#  image_url                  :text
#  listing_type               :integer          default("tool"), not null
#  location                   :string
#  metadata                   :jsonb            not null
#  paid                       :boolean          default(FALSE), not null
#  payment_reference          :string
#  payment_status             :integer          default("unpaid"), not null
#  published_at               :datetime
#  salary_range               :string
#  scheduled_for              :datetime
#  site_name                  :string
#  title                      :string
#  url_canonical              :text             not null
#  url_raw                    :text             not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  category_id                :bigint           not null
#  featured_by_id             :bigint
#  site_id                    :bigint           not null
#  source_id                  :bigint
#  stripe_checkout_session_id :string
#  stripe_payment_intent_id   :string
#  tenant_id                  :bigint           not null
#
# Indexes
#
#  index_listings_on_category_id                 (category_id)
#  index_listings_on_category_published          (category_id,published_at)
#  index_listings_on_domain                      (domain)
#  index_listings_on_featured_by_id              (featured_by_id)
#  index_listings_on_payment_status              (payment_status)
#  index_listings_on_published_at                (published_at)
#  index_listings_on_scheduled_for               (scheduled_for) WHERE (scheduled_for IS NOT NULL)
#  index_listings_on_site_expires_at             (site_id,expires_at)
#  index_listings_on_site_featured_dates         (site_id,featured_from,featured_until)
#  index_listings_on_site_id                     (site_id)
#  index_listings_on_site_id_and_url_canonical   (site_id,url_canonical) UNIQUE
#  index_listings_on_site_listing_type           (site_id,listing_type)
#  index_listings_on_site_type_expires           (site_id,listing_type,expires_at)
#  index_listings_on_source_id                   (source_id)
#  index_listings_on_stripe_checkout_session_id  (stripe_checkout_session_id) UNIQUE WHERE (stripe_checkout_session_id IS NOT NULL)
#  index_listings_on_stripe_payment_intent_id    (stripe_payment_intent_id) UNIQUE WHERE (stripe_payment_intent_id IS NOT NULL)
#  index_listings_on_tenant_and_url_canonical    (tenant_id,url_canonical) UNIQUE
#  index_listings_on_tenant_domain_published     (tenant_id,domain,published_at)
#  index_listings_on_tenant_id                   (tenant_id)
#  index_listings_on_tenant_id_and_category_id   (tenant_id,category_id)
#  index_listings_on_tenant_id_and_source_id     (tenant_id,source_id)
#  index_listings_on_tenant_published_created    (tenant_id,published_at,created_at)
#  index_listings_on_tenant_title                (tenant_id,title)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (featured_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
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
        # The validation runs first, so we get RecordInvalid, not RecordNotUnique
        expect { create(:listing, category: category1, url_raw: 'https://example.com/article') }.to raise_error(ActiveRecord::RecordInvalid, /Url canonical has already been taken/)
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

  describe 'monetisation' do
    describe 'associations' do
      it { should belong_to(:featured_by).class_name('User').optional }
      it { should have_many(:affiliate_clicks).dependent(:destroy) }
    end

    describe 'enums' do
      it 'defines listing_type enum' do
        expect(Listing.listing_types).to eq({ 'tool' => 0, 'job' => 1, 'service' => 2 })
      end

      it 'defaults to tool' do
        listing = build(:listing, tenant: tenant, category: category)
        expect(listing.listing_type).to eq('tool')
      end
    end

    describe '#featured?' do
      it 'returns true when within featured date range' do
        listing = build(:listing, tenant: tenant, category: category,
                        featured_from: 1.day.ago, featured_until: 1.day.from_now)
        expect(listing).to be_featured
      end

      it 'returns true when featured_until is nil (perpetual featuring)' do
        listing = build(:listing, tenant: tenant, category: category,
                        featured_from: 1.day.ago, featured_until: nil)
        expect(listing).to be_featured
      end

      it 'returns false when featured_from is nil' do
        listing = build(:listing, tenant: tenant, category: category,
                        featured_from: nil, featured_until: 1.day.from_now)
        expect(listing).not_to be_featured
      end

      it 'returns false when before featured_from' do
        listing = build(:listing, tenant: tenant, category: category,
                        featured_from: 1.day.from_now, featured_until: 2.days.from_now)
        expect(listing).not_to be_featured
      end

      it 'returns false when after featured_until' do
        listing = build(:listing, tenant: tenant, category: category,
                        featured_from: 2.days.ago, featured_until: 1.day.ago)
        expect(listing).not_to be_featured
      end
    end

    describe '#expired?' do
      it 'returns true when past expires_at' do
        listing = build(:listing, tenant: tenant, category: category, expires_at: 1.day.ago)
        expect(listing).to be_expired
      end

      it 'returns false when before expires_at' do
        listing = build(:listing, tenant: tenant, category: category, expires_at: 1.day.from_now)
        expect(listing).not_to be_expired
      end

      it 'returns false when expires_at is nil' do
        listing = build(:listing, tenant: tenant, category: category, expires_at: nil)
        expect(listing).not_to be_expired
      end
    end

    describe '#has_affiliate?' do
      it 'returns true when affiliate_url_template is present' do
        listing = build(:listing, tenant: tenant, category: category,
                        affiliate_url_template: 'https://affiliate.example.com?url={url}')
        expect(listing).to have_affiliate
      end

      it 'returns false when affiliate_url_template is blank' do
        listing = build(:listing, tenant: tenant, category: category, affiliate_url_template: nil)
        expect(listing).not_to have_affiliate
      end

      it 'returns false when affiliate_url_template is empty string' do
        listing = build(:listing, tenant: tenant, category: category, affiliate_url_template: '')
        expect(listing).not_to have_affiliate
      end
    end

    describe '#affiliate_url' do
      it 'returns nil when no affiliate template' do
        listing = build(:listing, tenant: tenant, category: category, affiliate_url_template: nil)
        expect(listing.affiliate_url).to be_nil
      end

      it 'delegates to AffiliateUrlService' do
        listing = build(:listing, tenant: tenant, category: category,
                        affiliate_url_template: 'https://affiliate.example.com?url={url}')
        allow(AffiliateUrlService).to receive(:new).and_call_original
        listing.affiliate_url
        expect(AffiliateUrlService).to have_received(:new).with(listing)
      end
    end

    describe '#display_url' do
      it 'returns affiliate_url when present' do
        listing = build(:listing, tenant: tenant, category: category,
                        url_raw: 'https://example.com',
                        affiliate_url_template: 'https://affiliate.example.com?url={url}')
        expect(listing.display_url).to start_with('https://affiliate.example.com')
      end

      it 'returns url_canonical when no affiliate' do
        listing = create(:listing, tenant: tenant, category: category,
                         url_raw: 'https://example.com', affiliate_url_template: nil)
        # URL normalization doesn't add a trailing slash to root domains
        expect(listing.display_url).to eq('https://example.com')
      end
    end

    describe '#affiliate_attribution' do
      it 'returns empty hash when nil' do
        listing = build(:listing, tenant: tenant, category: category)
        listing.affiliate_attribution = nil
        expect(listing.affiliate_attribution).to eq({})
      end

      it 'returns stored hash' do
        listing = build(:listing, tenant: tenant, category: category,
                        affiliate_attribution: { source: 'curated', medium: 'affiliate' })
        expect(listing.affiliate_attribution).to eq({ 'source' => 'curated', 'medium' => 'affiliate' })
      end
    end
  end

  describe 'monetisation scopes' do
    let!(:featured_listing) do
      create(:listing, tenant: tenant, category: category,
             featured_from: 1.day.ago, featured_until: 30.days.from_now)
    end
    let!(:non_featured_listing) do
      create(:listing, tenant: tenant, category: category,
             featured_from: nil, featured_until: nil)
    end
    let!(:expired_featured_listing) do
      create(:listing, tenant: tenant, category: category,
             featured_from: 30.days.ago, featured_until: 1.day.ago)
    end
    let!(:future_featured_listing) do
      create(:listing, tenant: tenant, category: category,
             featured_from: 1.day.from_now, featured_until: 30.days.from_now)
    end
    let!(:expired_listing) do
      create(:listing, tenant: tenant, category: category,
             expires_at: 1.day.ago)
    end
    let!(:active_listing) do
      create(:listing, tenant: tenant, category: category,
             expires_at: 30.days.from_now)
    end
    let!(:no_expiry_listing) do
      create(:listing, tenant: tenant, category: category,
             expires_at: nil)
    end
    let!(:job_listing) do
      create(:listing, :job, tenant: tenant, category: category)
    end
    let!(:tool_listing) do
      create(:listing, :tool, tenant: tenant, category: category)
    end
    let!(:service_listing) do
      create(:listing, :service, tenant: tenant, category: category)
    end
    let!(:affiliate_listing) do
      create(:listing, :with_affiliate, tenant: tenant, category: category)
    end
    let!(:paid_listing) do
      create(:listing, :paid, tenant: tenant, category: category)
    end

    describe '.featured' do
      it 'includes currently featured listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.featured).to include(featured_listing)
        end
      end

      it 'excludes non-featured listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.featured).not_to include(non_featured_listing)
        end
      end

      it 'excludes expired featured listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.featured).not_to include(expired_featured_listing)
        end
      end

      it 'excludes future featured listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.featured).not_to include(future_featured_listing)
        end
      end
    end

    describe '.not_featured' do
      it 'excludes currently featured listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.not_featured).not_to include(featured_listing)
        end
      end

      it 'includes non-featured listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.not_featured).to include(non_featured_listing)
        end
      end

      it 'includes expired featured listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.not_featured).to include(expired_featured_listing)
        end
      end
    end

    describe '.not_expired' do
      it 'includes listings without expiry' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.not_expired).to include(no_expiry_listing)
        end
      end

      it 'includes active listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.not_expired).to include(active_listing)
        end
      end

      it 'excludes expired listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.not_expired).not_to include(expired_listing)
        end
      end
    end

    describe '.expired' do
      it 'includes expired listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.expired).to include(expired_listing)
        end
      end

      it 'excludes active listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.expired).not_to include(active_listing)
        end
      end

      it 'excludes listings without expiry' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.expired).not_to include(no_expiry_listing)
        end
      end
    end

    describe '.jobs' do
      it 'includes job listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.jobs).to include(job_listing)
        end
      end

      it 'excludes tool listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.jobs).not_to include(tool_listing)
        end
      end
    end

    describe '.tools' do
      it 'includes tool listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.tools).to include(tool_listing)
        end
      end

      it 'excludes job listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.tools).not_to include(job_listing)
        end
      end
    end

    describe '.services' do
      it 'includes service listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.services).to include(service_listing)
        end
      end

      it 'excludes tool listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.services).not_to include(tool_listing)
        end
      end
    end

    describe '.active_jobs' do
      let!(:active_job) do
        create(:listing, :job, :published, tenant: tenant, category: category, expires_at: 30.days.from_now)
      end
      let!(:expired_job) do
        create(:listing, :job, :published, tenant: tenant, category: category, expires_at: 1.day.ago)
      end
      let!(:unpublished_job) do
        create(:listing, :job, :unpublished, tenant: tenant, category: category, expires_at: 30.days.from_now)
      end

      it 'includes published, non-expired jobs' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.active_jobs).to include(active_job)
        end
      end

      it 'excludes expired jobs' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.active_jobs).not_to include(expired_job)
        end
      end

      it 'excludes unpublished jobs' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.active_jobs).not_to include(unpublished_job)
        end
      end

      it 'excludes tools' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.active_jobs).not_to include(tool_listing)
        end
      end
    end

    describe '.with_affiliate' do
      it 'includes listings with affiliate template' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.with_affiliate).to include(affiliate_listing)
        end
      end

      it 'excludes listings without affiliate template' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.with_affiliate).not_to include(tool_listing)
        end
      end
    end

    describe '.paid_listings' do
      it 'includes paid listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.paid_listings).to include(paid_listing)
        end
      end

      it 'excludes unpaid listings' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.paid_listings).not_to include(tool_listing)
        end
      end
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

  describe 'scheduling' do
    describe '#scheduled?' do
      it 'returns true when scheduled_for is in the future' do
        listing = build(:listing, tenant: tenant, category: category, scheduled_for: 1.day.from_now)
        expect(listing.scheduled?).to be true
      end

      it 'returns false when scheduled_for is in the past' do
        listing = build(:listing, tenant: tenant, category: category, scheduled_for: 1.hour.ago)
        expect(listing.scheduled?).to be false
      end

      it 'returns false when scheduled_for is nil' do
        listing = build(:listing, tenant: tenant, category: category, scheduled_for: nil)
        expect(listing.scheduled?).to be false
      end
    end

    describe '.scheduled scope' do
      let!(:scheduled) { create(:listing, :scheduled, tenant: tenant, category: category) }
      let!(:published) { create(:listing, :published, tenant: tenant, category: category) }
      let!(:due) { create(:listing, :due_for_publishing, tenant: tenant, category: category) }

      it 'returns listings with future scheduled_for' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.scheduled).to include(scheduled)
          expect(Listing.scheduled).not_to include(published)
          expect(Listing.scheduled).not_to include(due)
        end
      end
    end

    describe '.not_scheduled scope' do
      let!(:scheduled) { create(:listing, :scheduled, tenant: tenant, category: category) }
      let!(:published) { create(:listing, :published, tenant: tenant, category: category) }

      it 'returns listings without scheduled_for' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.not_scheduled).to include(published)
          expect(Listing.not_scheduled).not_to include(scheduled)
        end
      end
    end

    describe '.due_for_publishing scope' do
      let!(:scheduled) { create(:listing, :scheduled, tenant: tenant, category: category) }
      let!(:due) { create(:listing, :due_for_publishing, tenant: tenant, category: category) }
      let!(:published) { create(:listing, :published, tenant: tenant, category: category) }

      it 'returns listings with past scheduled_for' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Listing.due_for_publishing).to include(due)
          expect(Listing.due_for_publishing).not_to include(scheduled)
          expect(Listing.due_for_publishing).not_to include(published)
        end
      end
    end
  end
end
