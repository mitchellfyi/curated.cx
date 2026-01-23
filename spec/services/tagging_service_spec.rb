# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaggingService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }

  describe ".tag" do
    it "delegates to instance call" do
      content_item = create(:content_item, site: site, source: source)
      expect_any_instance_of(described_class).to receive(:call)
      described_class.tag(content_item)
    end
  end

  describe "#call" do
    context "when content_item is blank" do
      it "returns empty result" do
        result = described_class.tag(nil)
        expect(result[:topic_tags]).to eq([])
        expect(result[:content_type]).to be_nil
        expect(result[:confidence]).to be_nil
        expect(result[:explanation]).to eq([])
      end
    end

    context "when content_item has no site" do
      it "returns empty result" do
        content_item = build(:content_item, site: nil, site_id: nil)
        result = described_class.tag(content_item)
        expect(result[:topic_tags]).to eq([])
      end
    end

    context "when no rules exist" do
      it "returns empty result" do
        content_item = create(:content_item, site: site, source: source)
        result = described_class.tag(content_item)
        expect(result[:topic_tags]).to eq([])
        expect(result[:content_type]).to be_nil
        expect(result[:confidence]).to be_nil
        expect(result[:explanation]).to eq([])
      end
    end

    context "with matching rules" do
      let(:taxonomy_tech) { create(:taxonomy, site: site, slug: "technology") }
      let(:taxonomy_news) { create(:taxonomy, site: site, slug: "news") }
      let(:content_item) do
        create(:content_item,
          site: site,
          source: source,
          url_canonical: "https://example.com/news/tech-article",
          title: "Technology Innovation")
      end

      describe "URL pattern matching" do
        it "tags content matching URL pattern with confidence 1.0" do
          create(:tagging_rule, :url_pattern,
            taxonomy: taxonomy_news,
            site: site,
            pattern: "example\\.com/news/.*",
            priority: 100)

          result = described_class.tag(content_item)
          expect(result[:topic_tags]).to include("news")
          expect(result[:confidence]).to eq(1.0)
          expect(result[:explanation].first[:taxonomy_slug]).to eq("news")
        end
      end

      describe "source-based matching" do
        it "tags content from specific source with confidence 0.9" do
          create(:tagging_rule, :source_based,
            taxonomy: taxonomy_tech,
            site: site,
            pattern: source.id.to_s,
            priority: 100)

          result = described_class.tag(content_item)
          expect(result[:topic_tags]).to include("technology")
          expect(result[:confidence]).to eq(0.9)
        end
      end

      describe "keyword matching" do
        it "tags content with matching keywords" do
          create(:tagging_rule, :keyword,
            taxonomy: taxonomy_tech,
            site: site,
            pattern: "technology, innovation",
            priority: 100)

          result = described_class.tag(content_item)
          expect(result[:topic_tags]).to include("technology")
          expect(result[:confidence]).to be >= 0.8 # 0.7 + (0.1 * 2)
        end
      end

      describe "domain matching" do
        it "tags content from matching domain with confidence 0.85" do
          create(:tagging_rule, :domain,
            taxonomy: taxonomy_news,
            site: site,
            pattern: "example.com",
            priority: 100)

          result = described_class.tag(content_item)
          expect(result[:topic_tags]).to include("news")
          expect(result[:confidence]).to eq(0.85)
        end
      end

      describe "multiple rules matching" do
        it "collects all matching tags" do
          create(:tagging_rule, :url_pattern,
            taxonomy: taxonomy_news,
            site: site,
            pattern: "example\\.com/news/.*",
            priority: 100)
          create(:tagging_rule, :keyword,
            taxonomy: taxonomy_tech,
            site: site,
            pattern: "technology",
            priority: 200)

          result = described_class.tag(content_item)
          expect(result[:topic_tags]).to include("news", "technology")
          expect(result[:explanation].size).to eq(2)
        end

        it "uses highest confidence from matching rules" do
          create(:tagging_rule, :url_pattern,
            taxonomy: taxonomy_news,
            site: site,
            pattern: "example\\.com/news/.*",
            priority: 100) # confidence 1.0
          create(:tagging_rule, :domain,
            taxonomy: taxonomy_tech,
            site: site,
            pattern: "example.com",
            priority: 200) # confidence 0.85

          result = described_class.tag(content_item)
          expect(result[:confidence]).to eq(1.0)
        end

        it "deduplicates tags when multiple rules match same taxonomy" do
          create(:tagging_rule, :url_pattern,
            taxonomy: taxonomy_news,
            site: site,
            pattern: "example\\.com/news/.*",
            priority: 100)
          create(:tagging_rule, :domain,
            taxonomy: taxonomy_news,
            site: site,
            pattern: "example.com",
            priority: 200)

          result = described_class.tag(content_item)
          expect(result[:topic_tags].count("news")).to eq(1)
        end
      end

      describe "priority ordering" do
        it "evaluates rules in priority order (lower number first)" do
          # Both rules match, but we verify processing order via explanation
          rule1 = create(:tagging_rule, :keyword,
            taxonomy: taxonomy_tech,
            site: site,
            pattern: "technology",
            priority: 10)
          rule2 = create(:tagging_rule, :keyword,
            taxonomy: taxonomy_news,
            site: site,
            pattern: "innovation",
            priority: 100)

          result = described_class.tag(content_item)
          rule_ids = result[:explanation].map { |e| e[:rule_id] }
          expect(rule_ids.first).to eq(rule1.id)
          expect(rule_ids.last).to eq(rule2.id)
        end
      end

      describe "disabled rules" do
        it "skips disabled rules" do
          create(:tagging_rule, :disabled,
            taxonomy: taxonomy_tech,
            site: site,
            pattern: "technology",
            priority: 100)

          result = described_class.tag(content_item)
          expect(result[:topic_tags]).to eq([])
        end
      end

      describe "explanation array" do
        it "builds explanation with rule details" do
          rule = create(:tagging_rule, :url_pattern,
            taxonomy: taxonomy_news,
            site: site,
            pattern: "example\\.com/news/.*",
            priority: 100)

          result = described_class.tag(content_item)
          explanation = result[:explanation].first
          expect(explanation[:rule_id]).to eq(rule.id)
          expect(explanation[:taxonomy_slug]).to eq("news")
          expect(explanation[:reason]).to include("URL matched pattern")
        end
      end
    end

    context "with rules from different sites" do
      let(:other_site) { create(:site, tenant: tenant) }
      let(:taxonomy) { create(:taxonomy, site: site, slug: "tech") }
      let(:other_taxonomy) { create(:taxonomy, site: other_site, slug: "other") }

      it "only applies rules from content item's site" do
        content_item = create(:content_item,
          site: site,
          source: source,
          title: "Technology Article")

        create(:tagging_rule, :keyword,
          taxonomy: taxonomy,
          site: site,
          pattern: "technology",
          priority: 100)
        create(:tagging_rule, :keyword,
          taxonomy: other_taxonomy,
          site: other_site,
          pattern: "technology",
          priority: 100)

        result = described_class.tag(content_item)
        expect(result[:topic_tags]).to eq([ "tech" ])
        expect(result[:topic_tags]).not_to include("other")
      end
    end
  end
end
