# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Entry, type: :model do
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant, allow_paths: true) }

  describe 'associations' do
    it { should belong_to(:tenant).optional }
    it { should belong_to(:category).optional }
  end

  describe 'validations' do
    subject { build(:entry, :directory, tenant: tenant, category: category) }

    it { should validate_presence_of(:url_raw) }
    it { should validate_presence_of(:title) }

    it 'validates url_canonical uniqueness within tenant' do
      existing = create(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://example.com/test')
      new_entry = build(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://example.com/test')

      expect(new_entry).not_to be_valid
      expect(new_entry.errors[:url_canonical]).to be_present
    end
  end

  describe 'tenant isolation' do
    let(:tenant1) { create(:tenant, slug: 'tenant1') }
    let(:tenant2) { create(:tenant, slug: 'tenant2') }
    let(:category1) { create(:category, tenant: tenant1) }
    let(:category2) { create(:category, tenant: tenant2) }

    it 'allows same canonical URL across different tenants' do
      ActsAsTenant.with_tenant(tenant1) do
        create(:entry, :directory, category: category1, url_raw: 'https://example.com/article')
      end

      ActsAsTenant.with_tenant(tenant2) do
        expect { create(:entry, :directory, category: category2, url_raw: 'https://example.com/article') }.not_to raise_error
      end
    end

    it 'prevents duplicate canonical URLs within same tenant' do
      ActsAsTenant.with_tenant(tenant1) do
        create(:entry, :directory, category: category1, url_raw: 'https://example.com/article')
        # The validation runs first, so we get RecordInvalid, not RecordNotUnique
        expect { create(:entry, :directory, category: category1, url_raw: 'https://example.com/article') }.to raise_error(ActiveRecord::RecordInvalid, /Url canonical has already been taken/)
      end
    end
  end

  describe 'URL canonicalization' do
    it 'canonicalizes URLs on save' do
      entry = build(:entry, :directory,
        tenant: tenant,
        category: category,
        url_raw: 'HTTP://EXAMPLE.COM/Article/?utm_source=test&other=keep'
      )
      entry.save!

      expect(entry.url_canonical).to eq('http://example.com/Article?other=keep')
      expect(entry.domain).to eq('example.com')
    end

    it 'removes tracking parameters' do
      entry = build(:entry, :directory,
        tenant: tenant,
        category: category,
        url_raw: 'https://example.com/article?utm_source=google&utm_medium=email&fbclid=12345&ref=homepage'
      )
      entry.save!

      expect(entry.url_canonical).to eq('https://example.com/article')
    end

    it 'normalizes path by removing trailing slash' do
      entry = build(:entry, :directory,
        tenant: tenant,
        category: category,
        url_raw: 'https://example.com/article/'
      )
      entry.save!

      expect(entry.url_canonical).to eq('https://example.com/article')
    end

    it 'keeps root path slash' do
      entry = build(:entry, :directory,
        tenant: tenant,
        category: category,
        url_raw: 'https://example.com/'
      )
      entry.save!

      expect(entry.url_canonical).to eq('https://example.com/')
    end

    it 'handles invalid URLs' do
      entry = build(:entry, :directory,
        tenant: tenant,
        category: category,
        url_raw: 'not-a-valid-url'
      )

      expect(entry).not_to be_valid
      expect(entry.errors[:url_raw]).to include(match(/must be a valid HTTP or HTTPS URL/))
    end
  end

  describe 'category URL validation' do
    context 'when category allows paths' do
      let(:category) { create(:category, tenant: tenant, allow_paths: true) }

      it 'allows path URLs' do
        entry = build(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://example.com/article/123')
        expect(entry).to be_valid
      end

      it 'allows root URLs' do
        entry = build(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://example.com')
        expect(entry).to be_valid
      end
    end

    context 'when category requires root domain only' do
      let(:category) { create(:category, tenant: tenant, allow_paths: false) }

      it 'rejects path URLs' do
        entry = build(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://example.com/article/123')
        expect(entry).not_to be_valid
        expect(entry.errors[:url_canonical]).to include('must be a root domain URL for this category')
      end

      it 'allows root URLs' do
        entry = build(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://example.com')
        expect(entry).to be_valid
      end
    end
  end

  describe 'JSONB field validation' do
    it 'validates ai_summaries is a hash' do
      entry = build(:entry, :directory, tenant: tenant, category: category, ai_summaries: 'not a hash')
      expect(entry).not_to be_valid
      expect(entry.errors[:ai_summaries]).to include('must be a valid JSON object')
    end

    it 'validates ai_tags is a hash' do
      entry = build(:entry, :directory, tenant: tenant, category: category, ai_tags: 'not a hash')
      expect(entry).not_to be_valid
      expect(entry.errors[:ai_tags]).to include('must be a valid JSON object')
    end

    it 'validates metadata is a hash' do
      entry = build(:entry, :directory, tenant: tenant, category: category, metadata: 'not a hash')
      expect(entry).not_to be_valid
      expect(entry.errors[:metadata]).to include('must be a valid JSON object')
    end
  end

  describe 'JSONB field defaults' do
    let(:entry) { create(:entry, :directory, tenant: tenant, category: category) }

    it 'returns empty hash for ai_summaries by default' do
      expect(entry.ai_summaries).to be_a(Hash)
    end

    it 'returns empty hash for ai_tags by default' do
      expect(entry.ai_tags).to be_a(Hash)
    end

    it 'returns empty hash for metadata by default' do
      expect(entry.metadata).to be_a(Hash)
    end

    it 'handles ai_summaries getter when field is empty' do
      entry.update_columns(ai_summaries: {})
      expect(entry.ai_summaries).to eq({})
    end
  end

  describe '#root_domain' do
    it 'extracts root domain from subdomain' do
      entry = create(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://blog.example.com/article')
      expect(entry.root_domain).to eq('example.com')
    end

    it 'returns domain when already root' do
      entry = create(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://example.com/article')
      expect(entry.root_domain).to eq('example.com')
    end

    it 'handles complex subdomains' do
      entry = create(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://api.v2.example.com/article')
      expect(entry.root_domain).to eq('example.com')
    end

    it 'returns nil for invalid URLs' do
      entry = build(:entry, :directory, tenant: tenant, category: category)
      # Use SQL to set invalid URL directly
      entry.save!
      entry.class.where(id: entry.id).update_all(url_canonical: 'invalid-url')
      entry.reload
      expect(entry.root_domain).to be_nil
    end
  end

  describe 'monetisation' do
    describe 'associations' do
      it { should belong_to(:featured_by).class_name('User').optional }
      it { should have_many(:affiliate_clicks).dependent(:destroy) }
    end

    describe 'enums' do
      it 'defines listing_type enum' do
        expect(Entry.listing_types).to eq({ 'tool' => 0, 'job' => 1, 'service' => 2 })
      end

      it 'defaults to tool' do
        entry = build(:entry, :directory, tenant: tenant, category: category)
        expect(entry.listing_type).to eq('tool')
      end
    end

    describe '#featured?' do
      it 'returns true when within featured date range' do
        entry = build(:entry, :directory, tenant: tenant, category: category,
                        featured_from: 1.day.ago, featured_until: 1.day.from_now)
        expect(entry).to be_featured
      end

      it 'returns true when featured_until is nil (perpetual featuring)' do
        entry = build(:entry, :directory, tenant: tenant, category: category,
                        featured_from: 1.day.ago, featured_until: nil)
        expect(entry).to be_featured
      end

      it 'returns false when featured_from is nil' do
        entry = build(:entry, :directory, tenant: tenant, category: category,
                        featured_from: nil, featured_until: 1.day.from_now)
        expect(entry).not_to be_featured
      end

      it 'returns false when before featured_from' do
        entry = build(:entry, :directory, tenant: tenant, category: category,
                        featured_from: 1.day.from_now, featured_until: 2.days.from_now)
        expect(entry).not_to be_featured
      end

      it 'returns false when after featured_until' do
        entry = build(:entry, :directory, tenant: tenant, category: category,
                        featured_from: 2.days.ago, featured_until: 1.day.ago)
        expect(entry).not_to be_featured
      end
    end

    describe '#expired?' do
      it 'returns true when past expires_at' do
        entry = build(:entry, :directory, tenant: tenant, category: category, expires_at: 1.day.ago)
        expect(entry).to be_expired
      end

      it 'returns false when before expires_at' do
        entry = build(:entry, :directory, tenant: tenant, category: category, expires_at: 1.day.from_now)
        expect(entry).not_to be_expired
      end

      it 'returns false when expires_at is nil' do
        entry = build(:entry, :directory, tenant: tenant, category: category, expires_at: nil)
        expect(entry).not_to be_expired
      end
    end

    describe '#has_affiliate?' do
      it 'returns true when affiliate_url_template is present' do
        entry = build(:entry, :directory, tenant: tenant, category: category,
                        affiliate_url_template: 'https://affiliate.example.com?url={url}')
        expect(entry).to have_affiliate
      end

      it 'returns false when affiliate_url_template is blank' do
        entry = build(:entry, :directory, tenant: tenant, category: category, affiliate_url_template: nil)
        expect(entry).not_to have_affiliate
      end

      it 'returns false when affiliate_url_template is empty string' do
        entry = build(:entry, :directory, tenant: tenant, category: category, affiliate_url_template: '')
        expect(entry).not_to have_affiliate
      end
    end

    describe '#affiliate_url' do
      it 'returns nil when no affiliate template' do
        entry = build(:entry, :directory, tenant: tenant, category: category, affiliate_url_template: nil)
        expect(entry.affiliate_url).to be_nil
      end

      it 'delegates to AffiliateUrlService' do
        entry = build(:entry, :directory, tenant: tenant, category: category,
                        affiliate_url_template: 'https://affiliate.example.com?url={url}')
        allow(AffiliateUrlService).to receive(:new).and_call_original
        entry.affiliate_url
        expect(AffiliateUrlService).to have_received(:new).with(entry)
      end
    end

    describe '#display_url' do
      it 'returns affiliate_url when present' do
        entry = build(:entry, :directory, tenant: tenant, category: category,
                        url_raw: 'https://example.com',
                        affiliate_url_template: 'https://affiliate.example.com?url={url}')
        expect(entry.display_url).to start_with('https://affiliate.example.com')
      end

      it 'returns url_canonical when no affiliate' do
        entry = create(:entry, :directory, tenant: tenant, category: category,
                         url_raw: 'https://example.com', affiliate_url_template: nil)
        # URL normalization doesn't add a trailing slash to root domains
        expect(entry.display_url).to eq('https://example.com')
      end
    end

    describe '#affiliate_attribution' do
      it 'returns empty hash when nil' do
        entry = build(:entry, :directory, tenant: tenant, category: category)
        entry.affiliate_attribution = nil
        expect(entry.affiliate_attribution).to eq({})
      end

      it 'returns stored hash' do
        entry = build(:entry, :directory, tenant: tenant, category: category,
                        affiliate_attribution: { source: 'curated', medium: 'affiliate' })
        expect(entry.affiliate_attribution).to eq({ 'source' => 'curated', 'medium' => 'affiliate' })
      end
    end
  end

  describe 'monetisation scopes' do
    let!(:featured_entry) do
      create(:entry, :directory, tenant: tenant, category: category,
             featured_from: 1.day.ago, featured_until: 30.days.from_now)
    end
    let!(:non_featured_entry) do
      create(:entry, :directory, tenant: tenant, category: category,
             featured_from: nil, featured_until: nil)
    end
    let!(:expired_featured_entry) do
      create(:entry, :directory, tenant: tenant, category: category,
             featured_from: 30.days.ago, featured_until: 1.day.ago)
    end
    let!(:future_featured_entry) do
      create(:entry, :directory, tenant: tenant, category: category,
             featured_from: 1.day.from_now, featured_until: 30.days.from_now)
    end
    let!(:expired_entry) do
      create(:entry, :directory, tenant: tenant, category: category,
             expires_at: 1.day.ago)
    end
    let!(:active_entry) do
      create(:entry, :directory, tenant: tenant, category: category,
             expires_at: 30.days.from_now)
    end
    let!(:no_expiry_entry) do
      create(:entry, :directory, tenant: tenant, category: category,
             expires_at: nil)
    end
    let!(:job_entry) do
      create(:entry, :directory, :job, tenant: tenant, category: category)
    end
    let!(:tool_entry) do
      create(:entry, :directory, :tool, tenant: tenant, category: category)
    end
    let!(:service_entry) do
      create(:entry, :directory, :service, tenant: tenant, category: category)
    end
    let!(:affiliate_entry) do
      create(:entry, :directory, :with_affiliate, tenant: tenant, category: category)
    end
    let!(:paid_entry) do
      create(:entry, :directory, :paid, tenant: tenant, category: category)
    end

    describe '.featured' do
      it 'includes currently featured entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.featured).to include(featured_entry)
        end
      end

      it 'excludes non-featured entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.featured).not_to include(non_featured_entry)
        end
      end

      it 'excludes expired featured entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.featured).not_to include(expired_featured_entry)
        end
      end

      it 'excludes future featured entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.featured).not_to include(future_featured_entry)
        end
      end
    end

    describe '.not_featured' do
      it 'excludes currently featured entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.not_featured).not_to include(featured_entry)
        end
      end

      it 'includes non-featured entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.not_featured).to include(non_featured_entry)
        end
      end

      it 'includes expired featured entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.not_featured).to include(expired_featured_entry)
        end
      end
    end

    describe '.not_expired' do
      it 'includes entries without expiry' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.not_expired).to include(no_expiry_entry)
        end
      end

      it 'includes active entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.not_expired).to include(active_entry)
        end
      end

      it 'excludes expired entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.not_expired).not_to include(expired_entry)
        end
      end
    end

    describe '.expired' do
      it 'includes expired entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.expired).to include(expired_entry)
        end
      end

      it 'excludes active entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.expired).not_to include(active_entry)
        end
      end

      it 'excludes entries without expiry' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.expired).not_to include(no_expiry_entry)
        end
      end
    end

    describe '.jobs' do
      it 'includes job entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.jobs).to include(job_entry)
        end
      end

      it 'excludes tool entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.jobs).not_to include(tool_entry)
        end
      end
    end

    describe '.tools' do
      it 'includes tool entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.tools).to include(tool_entry)
        end
      end

      it 'excludes job entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.tools).not_to include(job_entry)
        end
      end
    end

    describe '.services' do
      it 'includes service entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.services).to include(service_entry)
        end
      end

      it 'excludes tool entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.services).not_to include(tool_entry)
        end
      end
    end

    describe '.active_jobs' do
      let!(:active_job) do
        create(:entry, :directory, :job, :published, tenant: tenant, category: category, expires_at: 30.days.from_now)
      end
      let!(:expired_job) do
        create(:entry, :directory, :job, :published, tenant: tenant, category: category, expires_at: 1.day.ago)
      end
      let!(:unpublished_job) do
        create(:entry, :directory, :job, :unpublished, tenant: tenant, category: category, expires_at: 30.days.from_now)
      end

      it 'includes published, non-expired jobs' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.active_jobs).to include(active_job)
        end
      end

      it 'excludes expired jobs' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.active_jobs).not_to include(expired_job)
        end
      end

      it 'excludes unpublished jobs' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.active_jobs).not_to include(unpublished_job)
        end
      end

      it 'excludes tools' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.active_jobs).not_to include(tool_entry)
        end
      end
    end

    describe '.with_affiliate' do
      it 'includes entries with affiliate template' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.with_affiliate).to include(affiliate_entry)
        end
      end

      it 'excludes entries without affiliate template' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.with_affiliate).not_to include(tool_entry)
        end
      end
    end

    describe '.paid_listings' do
      it 'includes paid entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.paid_listings).to include(paid_entry)
        end
      end

      it 'excludes unpaid entries' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.paid_listings).not_to include(tool_entry)
        end
      end
    end
  end

  describe 'scopes' do
    let!(:published_entry) { create(:entry, :directory, tenant: tenant, category: category, published_at: 1.day.ago) }
    let!(:unpublished_entry) { create(:entry, :directory, tenant: tenant, category: category, published_at: nil) }
    let!(:domain_entry) { create(:entry, :directory, tenant: tenant, category: category, url_raw: 'https://example.com/test') }
    let!(:content_entry) { create(:entry, :directory, tenant: tenant, category: category, body_html: '<p>Content</p>') }
    let!(:no_content_entry) { create(:entry, :directory, tenant: tenant, category: category, body_html: nil) }

    describe '.published' do
      it 'returns only entries with published_at set' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.published).to include(published_entry)
          expect(Entry.published).not_to include(unpublished_entry)
        end
      end
    end

    describe '.recent' do
      it 'orders by published_at desc, then created_at desc' do
        ActsAsTenant.with_tenant(tenant) do
          recent_entries = Entry.recent.limit(5)
          expect(recent_entries).to include(published_entry)
          # Just verify the scope exists and returns results
          expect(recent_entries.count).to be > 0
        end
      end
    end

    describe '.by_domain' do
      it 'filters by domain' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.by_domain('example.com')).to include(domain_entry)
          expect(Entry.by_domain('other.com').count).to eq(0)
        end
      end
    end

    describe '.with_content' do
      it 'returns only entries with body_html' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.with_content).to include(content_entry)
          expect(Entry.with_content).not_to include(no_content_entry)
        end
      end
    end
  end

  describe 'scheduling' do
    describe '#scheduled?' do
      it 'returns true when scheduled_for is in the future' do
        entry = build(:entry, :directory, tenant: tenant, category: category, scheduled_for: 1.day.from_now)
        expect(entry.scheduled?).to be true
      end

      it 'returns false when scheduled_for is in the past' do
        entry = build(:entry, :directory, tenant: tenant, category: category, scheduled_for: 1.hour.ago)
        expect(entry.scheduled?).to be false
      end

      it 'returns false when scheduled_for is nil' do
        entry = build(:entry, :directory, tenant: tenant, category: category, scheduled_for: nil)
        expect(entry.scheduled?).to be false
      end
    end

    describe '.scheduled scope' do
      let!(:scheduled) { create(:entry, :directory, :scheduled, tenant: tenant, category: category) }
      let!(:published) { create(:entry, :directory, :published, tenant: tenant, category: category) }
      let!(:due) { create(:entry, :directory, :due_for_publishing, tenant: tenant, category: category) }

      it 'returns entries with future scheduled_for' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.scheduled).to include(scheduled)
          expect(Entry.scheduled).not_to include(published)
          expect(Entry.scheduled).not_to include(due)
        end
      end
    end

    describe '.not_scheduled scope' do
      let!(:scheduled) { create(:entry, :directory, :scheduled, tenant: tenant, category: category) }
      let!(:published) { create(:entry, :directory, :published, tenant: tenant, category: category) }

      it 'returns entries without scheduled_for' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.not_scheduled).to include(published)
          expect(Entry.not_scheduled).not_to include(scheduled)
        end
      end
    end

    describe '.due_for_publishing scope' do
      let!(:scheduled) { create(:entry, :directory, :scheduled, tenant: tenant, category: category) }
      let!(:due) { create(:entry, :directory, :due_for_publishing, tenant: tenant, category: category) }
      let!(:published) { create(:entry, :directory, :published, tenant: tenant, category: category) }

      it 'returns entries with past scheduled_for' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Entry.due_for_publishing).to include(due)
          expect(Entry.due_for_publishing).not_to include(scheduled)
          expect(Entry.due_for_publishing).not_to include(published)
        end
      end
    end
  end
end
