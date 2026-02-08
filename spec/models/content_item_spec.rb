# frozen_string_literal: true

# == Schema Information
#
# Table name: content_items
#
#  id                    :bigint           not null, primary key
#  ai_suggested_tags     :jsonb            not null
#  ai_summary            :text
#  comments_count        :integer          default(0), not null
#  comments_locked_at    :datetime
#  content_type          :string
#  description           :text
#  editorialised_at      :datetime
#  extracted_text        :text
#  hidden_at             :datetime
#  published_at          :datetime
#  raw_payload           :jsonb            not null
#  scheduled_for         :datetime
#  summary               :text
#  tagging_confidence    :decimal(3, 2)
#  tagging_explanation   :jsonb            not null
#  tags                  :jsonb            not null
#  title                 :string
#  topic_tags            :jsonb            not null
#  upvotes_count         :integer          default(0), not null
#  url_canonical         :string           not null
#  url_raw               :text             not null
#  why_it_matters        :text
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  comments_locked_by_id :bigint
#  hidden_by_id          :bigint
#  site_id               :bigint           not null
#  source_id             :bigint           not null
#
# Indexes
#
#  index_content_items_on_comments_locked_by_id         (comments_locked_by_id)
#  index_content_items_on_hidden_at                     (hidden_at)
#  index_content_items_on_hidden_by_id                  (hidden_by_id)
#  index_content_items_on_published_at                  (published_at)
#  index_content_items_on_scheduled_for                 (scheduled_for) WHERE (scheduled_for IS NOT NULL)
#  index_content_items_on_site_id                       (site_id)
#  index_content_items_on_site_id_and_content_type      (site_id,content_type)
#  index_content_items_on_site_id_and_editorialised_at  (site_id,editorialised_at)
#  index_content_items_on_site_id_and_url_canonical     (site_id,url_canonical) UNIQUE
#  index_content_items_on_site_id_published_at_desc     (site_id,published_at DESC)
#  index_content_items_on_source_id                     (source_id)
#  index_content_items_on_source_id_and_created_at      (source_id,created_at)
#  index_content_items_on_topic_tags_gin                (topic_tags) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (comments_locked_by_id => users.id)
#  fk_rails_...  (hidden_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#
require 'rails_helper'

RSpec.describe ContentItem, type: :model do
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
      create(:content_item, site: site, source: source, url_canonical: "https://example.com/article")

      duplicate = build(:content_item, site: site, source: source, url_canonical: "https://example.com/article")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:url_canonical]).to be_present
    end

    it "allows same url_canonical across different sites" do
      site1 = create(:site)
      site2 = create(:site)
      source1 = create(:source, site: site1)
      source2 = create(:source, site: site2)

      item1 = create(:content_item, site: site1, source: source1, url_canonical: "https://example.com/article")
      item2 = build(:content_item, site: site2, source: source2, url_canonical: "https://example.com/article")

      expect(item2).to be_valid
      expect(item2.save).to be true
    end
  end

  describe "deduplication" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    it "prevents duplicate content items by canonical URL per site" do
      url = "https://example.com/article?utm_source=test"

      item1 = ContentItem.create!(
        site: site,
        source: source,
        url_canonical: url,
        url_raw: url,
        raw_payload: { "original_url" => url },
        tags: [ "test" ]
      )

      # Try to create duplicate with same canonical URL
      duplicate = ContentItem.new(
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

      item1 = ContentItem.create!(
        site: site,
        source: source,
        url_canonical: canonical,
        url_raw: url1,
        raw_payload: { "original_url" => url1 },
        tags: [ "test" ]
      )

      # Second item with different raw URL but same canonical should fail validation
      duplicate = ContentItem.new(
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
      item1 = create(:content_item, site: site1, source: source1)
      item2 = create(:content_item, site: site2, source: source2)

      items = ContentItem.all
      expect(items).to include(item1)
      expect(items).not_to include(item2)
    end

    it "prevents accessing content items from other sites" do
      item1 = create(:content_item, site: site1, source: source1)
      item2 = create(:content_item, site: site2, source: source2)

      Current.site = site1
      expect {
        ContentItem.find(item2.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".find_or_initialize_by_canonical_url" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    it "finds existing content item by canonical URL" do
      existing = create(:content_item, site: site, source: source, url_canonical: "https://example.com/article")

      found = ContentItem.find_or_initialize_by_canonical_url(
        site: site,
        url_canonical: "https://example.com/article",
        source: source
      )

      expect(found).to be_persisted
      expect(found.id).to eq(existing.id)
    end

    it "initializes new content item if not found" do
      item = ContentItem.find_or_initialize_by_canonical_url(
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

      item = ContentItem.new(
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

      item = ContentItem.new(
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

      item1 = create(:content_item, site: site, source: source1)
      item2 = create(:content_item, site: site, source: source2)

      expect(ContentItem.by_source(source1)).to include(item1)
      expect(ContentItem.by_source(source1)).not_to include(item2)
    end

    it "filters published items" do
      published = create(:content_item, site: site, source: source, published_at: 1.hour.ago)
      unpublished = create(:content_item, :unpublished, site: site, source: source)

      expect(ContentItem.published).to include(published)
      expect(ContentItem.published).not_to include(unpublished)
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

      item = create(:content_item, site: site, source: source, raw_payload: payload)

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
        content_item = build(:content_item, site: site, source: source)
        content_item.editorialised_at = Time.current

        expect(content_item.editorialised?).to be true
      end

      it "returns false when editorialised_at is nil" do
        content_item = build(:content_item, site: site, source: source, editorialised_at: nil)

        expect(content_item.editorialised?).to be false
      end
    end

    describe "#ai_summary" do
      let(:source) { create(:source, site: site) }

      it "returns nil when not editorialised" do
        content_item = build(:content_item, site: site, source: source)

        expect(content_item.ai_summary).to be_nil
      end
    end

    describe "#ai_suggested_tags" do
      let(:source) { create(:source, site: site) }

      it "returns empty array by default" do
        content_item = build(:content_item, site: site, source: source)

        expect(content_item.ai_suggested_tags).to eq([])
      end
    end

    describe "after_create :enqueue_enrichment_pipeline" do
      let(:source) { create(:source, site: site) }

      it "enqueues EnrichContentItemJob" do
        expect {
          create(:content_item, site: site, source: source)
        }.to have_enqueued_job(EnrichContentItemJob)
      end

      it "passes the content item id to the job" do
        content_item = create(:content_item, site: site, source: source)

        expect(EnrichContentItemJob).to have_been_enqueued.with(content_item.id)
      end
    end
  end

  describe "scheduling" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    describe "#scheduled?" do
      it "returns true when scheduled_for is in the future" do
        content_item = build(:content_item, site: site, source: source, scheduled_for: 1.day.from_now)
        expect(content_item.scheduled?).to be true
      end

      it "returns false when scheduled_for is in the past" do
        content_item = build(:content_item, site: site, source: source, scheduled_for: 1.hour.ago)
        expect(content_item.scheduled?).to be false
      end

      it "returns false when scheduled_for is nil" do
        content_item = build(:content_item, site: site, source: source, scheduled_for: nil)
        expect(content_item.scheduled?).to be false
      end
    end

    describe ".scheduled scope" do
      it "returns content items with future scheduled_for" do
        scheduled = create(:content_item, :scheduled, site: site, source: source)
        published = create(:content_item, :published, site: site, source: source)
        due = create(:content_item, :due_for_publishing, site: site, source: source)

        expect(ContentItem.scheduled).to include(scheduled)
        expect(ContentItem.scheduled).not_to include(published)
        expect(ContentItem.scheduled).not_to include(due)
      end
    end

    describe ".not_scheduled scope" do
      it "returns content items without scheduled_for" do
        scheduled = create(:content_item, :scheduled, site: site, source: source)
        published = create(:content_item, :published, site: site, source: source)

        expect(ContentItem.not_scheduled).to include(published)
        expect(ContentItem.not_scheduled).not_to include(scheduled)
      end
    end

    describe ".due_for_publishing scope" do
      it "returns content items with past scheduled_for" do
        scheduled = create(:content_item, :scheduled, site: site, source: source)
        due = create(:content_item, :due_for_publishing, site: site, source: source)
        published = create(:content_item, :published, site: site, source: source)

        expect(ContentItem.due_for_publishing).to include(due)
        expect(ContentItem.due_for_publishing).not_to include(scheduled)
        expect(ContentItem.due_for_publishing).not_to include(published)
      end
    end

    describe ".for_feed scope" do
      it "excludes scheduled items" do
        scheduled = create(:content_item, :scheduled, site: site, source: source)
        published = create(:content_item, :published, site: site, source: source)
        hidden = create(:content_item, :hidden, site: site, source: source)
        unpublished = create(:content_item, :unpublished, site: site, source: source)

        expect(ContentItem.for_feed).to include(published)
        expect(ContentItem.for_feed).not_to include(scheduled)
        expect(ContentItem.for_feed).not_to include(hidden)
        expect(ContentItem.for_feed).not_to include(unpublished)
      end
    end
  end
end
