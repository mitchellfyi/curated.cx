# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Entry, type: :model do
  describe "associations" do
    it { should belong_to(:site) }
    it { should belong_to(:source) }
  end

  describe "validations" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    it { should validate_presence_of(:url_canonical) }
    it { should validate_presence_of(:url_raw) }
    it { should validate_presence_of(:raw_payload) }

    it "validates uniqueness of url_canonical scoped to site" do
      create(:entry, :feed, site: site, source: source, url_canonical: "https://example.com/article")

      duplicate = build(:entry, :feed, site: site, source: source, url_canonical: "https://example.com/article")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:url_canonical]).to be_present
    end

    it "allows same url_canonical across different sites" do
      site1 = create(:site)
      site2 = create(:site)
      source1 = create(:source, site: site1)
      source2 = create(:source, site: site2)

      item1 = create(:entry, :feed, site: site1, source: source1, url_canonical: "https://example.com/article")
      item2 = build(:entry, :feed, site: site2, source: source2, url_canonical: "https://example.com/article")

      expect(item2).to be_valid
      expect(item2.save).to be true
    end
  end

  describe "deduplication" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    it "prevents duplicate entries by canonical URL per site" do
      url = "https://example.com/article?utm_source=test"

      item1 = Entry.create!(
        site: site,
        source: source,
        url_canonical: url,
        url_raw: url,
        raw_payload: { "original_url" => url },
        tags: [ "test" ]
      )

      # Try to create duplicate with same canonical URL
      duplicate = Entry.new(
        site: site,
        source: source,
        url_canonical: url,
        url_raw: url + "&utm_medium=email",
        raw_payload: { "original_url" => url },
        tags: [ "test" ]
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:url_canonical]).to be_present
    end

    it "allows different raw URLs that canonicalize to the same URL" do
      url1 = "https://example.com/article?utm_source=test"
      url2 = "https://example.com/article?utm_medium=email"
      canonical = "https://example.com/article"

      item1 = Entry.create!(
        site: site,
        source: source,
        url_canonical: canonical,
        url_raw: url1,
        raw_payload: { "original_url" => url1 },
        tags: [ "test" ]
      )

      # Second item with different raw URL but same canonical should fail validation
      duplicate = Entry.new(
        site: site,
        source: source,
        url_canonical: canonical,
        url_raw: url2,
        raw_payload: { "original_url" => url2 },
        tags: [ "test" ]
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:url_canonical]).to be_present
    end
  end

  describe "scoping to Site" do
    let(:tenant) { create(:tenant) }
    let(:site1) { create(:site, tenant: tenant) }
    let(:site2) { create(:site, tenant: tenant) }
    let(:source1) { create(:source, site: site1) }
    let(:source2) { create(:source, site: site2) }

    before do
      Current.site = site1
    end

    it "scopes queries to current site" do
      item1 = create(:entry, :feed, site: site1, source: source1)
      item2 = create(:entry, :feed, site: site2, source: source2)

      items = Entry.all
      expect(items).to include(item1)
      expect(items).not_to include(item2)
    end

    it "prevents accessing entries from other sites" do
      item1 = create(:entry, :feed, site: site1, source: source1)
      item2 = create(:entry, :feed, site: site2, source: source2)

      Current.site = site1
      expect {
        Entry.find(item2.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".find_or_initialize_by_canonical_url" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    it "finds existing entry by canonical URL" do
      existing = create(:entry, :feed, site: site, source: source, url_canonical: "https://example.com/article")

      found = Entry.find_or_initialize_by_canonical_url(
        site: site,
        url_canonical: "https://example.com/article",
        source: source
      )

      expect(found).to be_persisted
      expect(found.id).to eq(existing.id)
    end

    it "initializes new entry if not found" do
      item = Entry.find_or_initialize_by_canonical_url(
        site: site,
        url_canonical: "https://example.com/new-article",
        source: source
      )

      expect(item).not_to be_persisted
      expect(item.url_canonical).to eq("https://example.com/new-article")
      expect(item.source).to eq(source)
      expect(item.url_raw).to eq("https://example.com/new-article")
    end
  end

  describe "callbacks" do
    it "normalizes url_canonical before validation" do
      site = create(:site)
      source = create(:source, site: site)

      item = Entry.new(
        site: site,
        source: source,
        url_canonical: "HTTP://EXAMPLE.COM/Article?utm_source=test",
        url_raw: "http://example.com/article?utm_source=test",
        raw_payload: {},
        tags: []
      )
      item.valid?

      expect(item.url_canonical).to eq("http://example.com/Article")
    end

    it "ensures tags is always an array" do
      site = create(:site)
      source = create(:source, site: site)

      item = Entry.new(
        site: site,
        source: source,
        url_canonical: "https://example.com/article",
        url_raw: "https://example.com/article",
        raw_payload: {},
        tags: nil
      )
      item.valid?

      expect(item.tags).to eq([])
    end
  end

  describe "scopes" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    it "filters by source" do
      source1 = create(:source, site: site)
      source2 = create(:source, site: site)

      item1 = create(:entry, :feed, site: site, source: source1)
      item2 = create(:entry, :feed, site: site, source: source2)

      expect(Entry.by_source(source1)).to include(item1)
      expect(Entry.by_source(source1)).not_to include(item2)
    end

    it "filters published items" do
      published = create(:entry, :feed, site: site, source: source, published_at: 1.hour.ago)
      unpublished = create(:entry, :feed, :unpublished, site: site, source: source)

      expect(Entry.published).to include(published)
      expect(Entry.published).not_to include(unpublished)
    end
  end

  describe "raw_payload storage" do
    it "stores raw payload for audit and debugging" do
      site = create(:site)
      source = create(:source, site: site)

      payload = {
        "original_title" => "Test Article",
        "original_url" => "https://example.com/article?utm_source=test",
        "fetched_at" => Time.current.iso8601,
        "source_data" => { "author" => "John Doe" }
      }

      item = create(:entry, :feed, site: site, source: source, raw_payload: payload)

      expect(item.raw_payload).to eq(payload)
      expect(item.raw_payload["original_title"]).to eq("Test Article")
    end
  end

  describe "editorialisation integration" do
    include ActiveJob::TestHelper

    let(:site) { create(:site) }

    describe "#editorialised?" do
      let(:source) { create(:source, site: site) }

      it "returns true when editorialised_at is present" do
        entry = build(:entry, :feed, site: site, source: source)
        entry.editorialised_at = Time.current

        expect(entry.editorialised?).to be true
      end

      it "returns false when editorialised_at is nil" do
        entry = build(:entry, :feed, site: site, source: source, editorialised_at: nil)

        expect(entry.editorialised?).to be false
      end
    end

    describe "#ai_summary" do
      let(:source) { create(:source, site: site) }

      it "returns nil when not editorialised" do
        entry = build(:entry, :feed, site: site, source: source)

        expect(entry.ai_summary).to be_nil
      end
    end

    describe "#ai_suggested_tags" do
      let(:source) { create(:source, site: site) }

      it "returns empty array by default" do
        entry = build(:entry, :feed, site: site, source: source)

        expect(entry.ai_suggested_tags).to eq([])
      end
    end

    describe "after_create :enqueue_enrichment_pipeline" do
      let(:source) { create(:source, site: site) }

      it "enqueues EnrichEntryJob" do
        expect {
          create(:entry, :feed, site: site, source: source)
        }.to have_enqueued_job(EnrichEntryJob)
      end

      it "passes the entry id to the job" do
        entry = create(:entry, :feed, site: site, source: source)

        expect(EnrichEntryJob).to have_been_enqueued.with(entry.id)
      end
    end
  end

  describe "scheduling" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    describe "#scheduled?" do
      it "returns true when scheduled_for is in the future" do
        entry = build(:entry, :feed, site: site, source: source, scheduled_for: 1.day.from_now)
        expect(entry.scheduled?).to be true
      end

      it "returns false when scheduled_for is in the past" do
        entry = build(:entry, :feed, site: site, source: source, scheduled_for: 1.hour.ago)
        expect(entry.scheduled?).to be false
      end

      it "returns false when scheduled_for is nil" do
        entry = build(:entry, :feed, site: site, source: source, scheduled_for: nil)
        expect(entry.scheduled?).to be false
      end
    end

    describe ".scheduled scope" do
      it "returns entries with future scheduled_for" do
        scheduled = create(:entry, :feed, :scheduled, site: site, source: source)
        published = create(:entry, :feed, :published, site: site, source: source)
        due = create(:entry, :feed, :due_for_publishing, site: site, source: source)

        expect(Entry.scheduled).to include(scheduled)
        expect(Entry.scheduled).not_to include(published)
        expect(Entry.scheduled).not_to include(due)
      end
    end

    describe ".not_scheduled scope" do
      it "returns entries without scheduled_for" do
        scheduled = create(:entry, :feed, :scheduled, site: site, source: source)
        published = create(:entry, :feed, :published, site: site, source: source)

        expect(Entry.not_scheduled).to include(published)
        expect(Entry.not_scheduled).not_to include(scheduled)
      end
    end

    describe ".due_for_publishing scope" do
      it "returns entries with past scheduled_for" do
        scheduled = create(:entry, :feed, :scheduled, site: site, source: source)
        due = create(:entry, :feed, :due_for_publishing, site: site, source: source)
        published = create(:entry, :feed, :published, site: site, source: source)

        expect(Entry.due_for_publishing).to include(due)
        expect(Entry.due_for_publishing).not_to include(scheduled)
        expect(Entry.due_for_publishing).not_to include(published)
      end
    end

    describe ".for_feed scope" do
      it "excludes scheduled items" do
        scheduled = create(:entry, :feed, :scheduled, site: site, source: source)
        published = create(:entry, :feed, :published, site: site, source: source)
        hidden = create(:entry, :feed, :hidden, site: site, source: source)
        unpublished = create(:entry, :feed, :unpublished, site: site, source: source)

        expect(Entry.for_feed).to include(published)
        expect(Entry.for_feed).not_to include(scheduled)
        expect(Entry.for_feed).not_to include(hidden)
        expect(Entry.for_feed).not_to include(unpublished)
      end
    end
  end
end
