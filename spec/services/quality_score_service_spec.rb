# frozen_string_literal: true

require "rails_helper"

RSpec.describe QualityScoreService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }

  before do
    allow_any_instance_of(Entry).to receive(:enqueue_enrichment_pipeline)
  end

  describe ".score" do
    it "returns a numeric score between 0 and 10" do
      entry = create(:entry, :feed, site: site, source: source)
      score = described_class.score(entry)

      expect(score).to be_a(Numeric)
      expect(score).to be >= 0.0
      expect(score).to be <= 10.0
    end

    it "gives higher scores to content with more metadata" do
      minimal = create(:entry, :feed, site: site, source: source,
        description: nil, extracted_text: nil, published_at: nil)
      rich = create(:entry, :feed, :with_enhanced_editorial, site: site, source: source,
        extracted_text: "word " * 500,
        og_image_url: "https://example.com/image.jpg",
        author_name: "Test Author",
        read_time_minutes: 5)

      expect(described_class.score(rich)).to be > described_class.score(minimal)
    end
  end

  describe ".score!" do
    it "updates the content item quality_score column" do
      entry = create(:entry, :feed, site: site, source: source)

      expect {
        described_class.score!(entry)
      }.to change { entry.reload.quality_score }.from(nil)

      expect(entry.quality_score).to be_a(BigDecimal)
    end
  end

  describe "scoring dimensions" do
    context "content depth" do
      it "scores higher for longer content" do
        short = create(:entry, :feed, site: site, source: source,
          extracted_text: "short", word_count: 50)
        long = create(:entry, :feed, site: site, source: source,
          extracted_text: "word " * 500, word_count: 500)

        expect(described_class.score(long)).to be > described_class.score(short)
      end
    end

    context "freshness" do
      it "scores higher for recent content" do
        old_item = create(:entry, :feed, site: site, source: source,
          published_at: 6.months.ago)
        new_item = create(:entry, :feed, site: site, source: source,
          published_at: 1.hour.ago)

        expect(described_class.score(new_item)).to be > described_class.score(old_item)
      end
    end

    context "engagement" do
      it "scores higher for content with more engagement" do
        low = create(:entry, :feed, :low_engagement, site: site, source: source)
        high = create(:entry, :feed, :high_engagement, site: site, source: source)

        expect(described_class.score(high)).to be > described_class.score(low)
      end
    end
  end
end
