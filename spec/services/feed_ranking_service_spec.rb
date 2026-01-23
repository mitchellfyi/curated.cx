# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeedRankingService do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site, quality_weight: 1.0) }
  let(:high_quality_source) { create(:source, site: site, quality_weight: 2.0) }
  let(:low_quality_source) { create(:source, site: site, quality_weight: 0.5) }

  before do
    setup_tenant_context(tenant)
  end

  describe ".ranked_feed" do
    it "returns ContentItems for the given site" do
      item = create(:content_item, :published, site: site, source: source)
      other_site = create(:site, tenant: tenant)
      other_source = create(:source, site: other_site)
      other_item = create(:content_item, :published, site: other_site, source: other_source)

      result = described_class.ranked_feed(site: site)

      expect(result).to include(item)
      expect(result).not_to include(other_item)
    end

    it "only returns published items" do
      published = create(:content_item, :published, site: site, source: source)
      unpublished = create(:content_item, :unpublished, site: site, source: source)

      result = described_class.ranked_feed(site: site)

      expect(result).to include(published)
      expect(result).not_to include(unpublished)
    end

    it "respects limit parameter" do
      create_list(:content_item, 5, :published, site: site, source: source)

      result = described_class.ranked_feed(site: site, limit: 3)

      expect(result.count).to eq(3)
    end

    it "respects offset parameter" do
      items = create_list(:content_item, 5, :published, site: site, source: source)
                .sort_by(&:published_at).reverse

      result = described_class.ranked_feed(site: site, filters: { sort: "latest" }, limit: 2, offset: 2)

      expect(result.to_a).to eq(items[2..3])
    end
  end

  describe "filtering" do
    describe "by tag" do
      let!(:tagged_item) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(topic_tags: [ "tech", "ai" ])
        item
      end

      let!(:untagged_item) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(topic_tags: [ "sports" ])
        item
      end

      it "filters by tag when provided" do
        result = described_class.ranked_feed(site: site, filters: { tag: "tech" })

        expect(result).to include(tagged_item)
        expect(result).not_to include(untagged_item)
      end

      it "returns all items when tag filter is blank" do
        result = described_class.ranked_feed(site: site, filters: { tag: "" })

        expect(result).to include(tagged_item, untagged_item)
      end
    end

    describe "by content type" do
      let!(:article) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(content_type: "article")
        item
      end

      let!(:video) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(content_type: "video")
        item
      end

      it "filters by content_type when provided" do
        result = described_class.ranked_feed(site: site, filters: { content_type: "article" })

        expect(result).to include(article)
        expect(result).not_to include(video)
      end

      it "returns all items when content_type filter is blank" do
        result = described_class.ranked_feed(site: site, filters: { content_type: "" })

        expect(result).to include(article, video)
      end
    end

    describe "combined filters" do
      before do
        # Clear any existing items
        ContentItem.where(site: site).delete_all
      end

      let!(:tech_article) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(topic_tags: [ "tech" ], content_type: "article")
        item
      end

      let!(:tech_video) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(topic_tags: [ "tech" ], content_type: "video")
        item
      end

      let!(:sports_article) do
        item = create(:content_item, :published, site: site, source: source)
        item.update_columns(topic_tags: [ "sports" ], content_type: "article")
        item
      end

      it "applies multiple filters together" do
        result = described_class.ranked_feed(
          site: site,
          filters: { tag: "tech", content_type: "article" }
        )

        expect(result).to contain_exactly(tech_article)
      end
    end
  end

  describe "sorting" do
    describe "latest sort" do
      it "orders by published_at descending" do
        old_item = create(:content_item, :published, site: site, source: source, published_at: 2.days.ago)
        new_item = create(:content_item, :published, site: site, source: source, published_at: 1.hour.ago)

        result = described_class.ranked_feed(site: site, filters: { sort: "latest" })

        expect(result.first).to eq(new_item)
        expect(result.last).to eq(old_item)
      end
    end

    describe "top_week sort" do
      before do
        ContentItem.where(site: site).delete_all
      end

      let!(:old_high_engagement) do
        item = create(:content_item, :published, site: site, source: source, published_at: 2.weeks.ago)
        item.update_columns(upvotes_count: 100, comments_count: 50)
        item
      end

      let!(:recent_low_engagement) do
        item = create(:content_item, :published, site: site, source: source, published_at: 1.day.ago)
        item.update_columns(upvotes_count: 1, comments_count: 0)
        item
      end

      let!(:recent_high_engagement) do
        item = create(:content_item, :published, site: site, source: source, published_at: 2.days.ago)
        item.update_columns(upvotes_count: 50, comments_count: 25)
        item
      end

      it "only includes items from the past week" do
        result = described_class.ranked_feed(site: site, filters: { sort: "top_week" })

        expect(result).to include(recent_low_engagement, recent_high_engagement)
        expect(result).not_to include(old_high_engagement)
      end

      it "orders by engagement score descending" do
        result = described_class.ranked_feed(site: site, filters: { sort: "top_week" })

        expect(result.first).to eq(recent_high_engagement)
        expect(result.last).to eq(recent_low_engagement)
      end
    end

    describe "ranked sort (default)" do
      before do
        ContentItem.where(site: site).delete_all
      end

      it "ranks newer items higher than older items (freshness decay)" do
        old_item = create(:content_item, :published, site: site, source: source, published_at: 3.days.ago)
        old_item.update_columns(upvotes_count: 0, comments_count: 0)

        new_item = create(:content_item, :published, site: site, source: source, published_at: 1.hour.ago)
        new_item.update_columns(upvotes_count: 0, comments_count: 0)

        result = described_class.ranked_feed(site: site, filters: { sort: "ranked" })

        expect(result.first).to eq(new_item)
        expect(result.last).to eq(old_item)
      end

      it "ranks items from high quality sources higher" do
        low_quality_item = create(:content_item, :published, site: site, source: low_quality_source, published_at: 1.hour.ago)
        low_quality_item.update_columns(upvotes_count: 0, comments_count: 0)

        high_quality_item = create(:content_item, :published, site: site, source: high_quality_source, published_at: 1.hour.ago)
        high_quality_item.update_columns(upvotes_count: 0, comments_count: 0)

        result = described_class.ranked_feed(site: site, filters: { sort: "ranked" })

        expect(result.first).to eq(high_quality_item)
        expect(result.last).to eq(low_quality_item)
      end

      it "ranks items with higher engagement higher" do
        low_engagement = create(:content_item, :published, site: site, source: source, published_at: 1.hour.ago)
        low_engagement.update_columns(upvotes_count: 0, comments_count: 0)

        high_engagement = create(:content_item, :published, site: site, source: source, published_at: 1.hour.ago)
        high_engagement.update_columns(upvotes_count: 100, comments_count: 50)

        result = described_class.ranked_feed(site: site, filters: { sort: "ranked" })

        expect(result.first).to eq(high_engagement)
        expect(result.last).to eq(low_engagement)
      end

      it "uses default sort when sort parameter is invalid" do
        old_item = create(:content_item, :published, site: site, source: source, published_at: 2.days.ago)
        new_item = create(:content_item, :published, site: site, source: source, published_at: 1.hour.ago)

        # Invalid sort should fall back to latest (published_at desc)
        result = described_class.ranked_feed(site: site, filters: { sort: "invalid" })

        expect(result.first).to eq(new_item)
      end
    end
  end

  describe "constants" do
    it "has ranking weights that sum to 1.0" do
      total = described_class::FRESHNESS_WEIGHT +
              described_class::SOURCE_QUALITY_WEIGHT +
              described_class::ENGAGEMENT_WEIGHT

      expect(total).to eq(1.0)
    end

    it "has valid sort modes" do
      expect(described_class::VALID_SORTS).to contain_exactly("ranked", "latest", "top_week")
    end
  end
end
