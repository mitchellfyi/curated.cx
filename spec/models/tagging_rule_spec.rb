# frozen_string_literal: true

# == Schema Information
#
# Table name: tagging_rules
#
#  id          :bigint           not null, primary key
#  enabled     :boolean          default(TRUE), not null
#  pattern     :text             not null
#  priority    :integer          default(100), not null
#  rule_type   :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  site_id     :bigint           not null
#  taxonomy_id :bigint           not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_tagging_rules_on_site_id               (site_id)
#  index_tagging_rules_on_site_id_and_enabled   (site_id,enabled)
#  index_tagging_rules_on_site_id_and_priority  (site_id,priority)
#  index_tagging_rules_on_taxonomy_id           (taxonomy_id)
#  index_tagging_rules_on_tenant_id             (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (taxonomy_id => taxonomies.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
require "rails_helper"

RSpec.describe TaggingRule, type: :model do
  describe "associations" do
    it { should belong_to(:site) }
    it { should belong_to(:tenant) }
    it { should belong_to(:taxonomy) }
  end

  describe "validations" do
    let(:taxonomy) { create(:taxonomy) }
    subject { build(:tagging_rule, taxonomy: taxonomy) }

    it { should validate_presence_of(:pattern) }
    it { should validate_presence_of(:priority) }
    it { should validate_numericality_of(:priority).only_integer }
    it { should validate_presence_of(:rule_type) }

    it "validates enabled is boolean" do
      rule = build(:tagging_rule, taxonomy: taxonomy, enabled: nil)
      expect(rule).not_to be_valid
      expect(rule.errors[:enabled]).to be_present
    end
  end

  describe "enums" do
    it { should define_enum_for(:rule_type).with_values(url_pattern: 0, source: 1, keyword: 2, domain: 3) }
  end

  describe "scopes" do
    let(:taxonomy) { create(:taxonomy) }
    let(:site) { taxonomy.site }

    describe ".enabled" do
      it "returns only enabled rules" do
        enabled = create(:tagging_rule, taxonomy: taxonomy, site: site, enabled: true)
        disabled = create(:tagging_rule, :disabled, taxonomy: taxonomy, site: site)

        rules = TaggingRule.without_site_scope.where(site: site).enabled
        expect(rules).to include(enabled)
        expect(rules).not_to include(disabled)
      end
    end

    describe ".by_priority" do
      it "orders by priority ascending" do
        low_priority = create(:tagging_rule, :low_priority, taxonomy: taxonomy, site: site)
        high_priority = create(:tagging_rule, :high_priority, taxonomy: taxonomy, site: site)

        rules = TaggingRule.without_site_scope.where(site: site).by_priority
        expect(rules.first).to eq(high_priority)
        expect(rules.last).to eq(low_priority)
      end
    end

    describe ".for_type" do
      it "filters by rule type" do
        url_rule = create(:tagging_rule, :url_pattern, taxonomy: taxonomy, site: site)
        keyword_rule = create(:tagging_rule, :keyword, taxonomy: taxonomy, site: site)

        rules = TaggingRule.without_site_scope.where(site: site).for_type(:url_pattern)
        expect(rules).to include(url_rule)
        expect(rules).not_to include(keyword_rule)
      end
    end
  end

  describe "#matches?" do
    let(:taxonomy) { create(:taxonomy) }
    let(:site) { taxonomy.site }
    let(:source) { create(:source, site: site) }
    let(:entry) do
      create(:entry, :feed,
        site: site,
        source: source,
        url_canonical: "https://example.com/news/article-1",
        title: "Technology Innovation Startup",
        extracted_text: "This is about technology and innovation",
        description: "A startup story")
    end

    describe "when rule is disabled" do
      it "returns no match" do
        rule = create(:tagging_rule, :disabled, taxonomy: taxonomy, site: site)
        result = rule.matches?(entry)
        expect(result[:match]).to be false
        expect(result[:confidence]).to eq(0.0)
      end
    end

    describe "url_pattern rule type" do
      it "matches URL with regex pattern" do
        rule = create(:tagging_rule, :url_pattern, taxonomy: taxonomy, site: site,
          pattern: "example\\.com/news/.*")
        result = rule.matches?(entry)
        expect(result[:match]).to be true
        expect(result[:confidence]).to eq(1.0)
        expect(result[:reason]).to include("URL matched pattern")
      end

      it "does not match non-matching URL" do
        rule = create(:tagging_rule, :url_pattern, taxonomy: taxonomy, site: site,
          pattern: "other\\.com/.*")
        result = rule.matches?(entry)
        expect(result[:match]).to be false
      end

      it "handles invalid regex gracefully" do
        rule = create(:tagging_rule, :url_pattern, taxonomy: taxonomy, site: site,
          pattern: "[invalid(regex")
        result = rule.matches?(entry)
        expect(result[:match]).to be false
      end

      it "handles blank URL" do
        item = build(:entry, :feed, site: site, source: source, url_canonical: nil)
        rule = create(:tagging_rule, :url_pattern, taxonomy: taxonomy, site: site)
        result = rule.matches?(item)
        expect(result[:match]).to be false
      end
    end

    describe "source rule type" do
      it "matches content from specified source" do
        rule = create(:tagging_rule, :source_based, taxonomy: taxonomy, site: site,
          pattern: source.id.to_s)
        result = rule.matches?(entry)
        expect(result[:match]).to be true
        expect(result[:confidence]).to eq(0.9)
        expect(result[:reason]).to include("Content from source")
      end

      it "does not match content from different source" do
        other_source = create(:source, site: site)
        rule = create(:tagging_rule, :source_based, taxonomy: taxonomy, site: site,
          pattern: other_source.id.to_s)
        result = rule.matches?(entry)
        expect(result[:match]).to be false
      end

      it "handles blank source_id" do
        item = build(:entry, :feed, site: site, source: nil, source_id: nil)
        rule = create(:tagging_rule, :source_based, taxonomy: taxonomy, site: site)
        result = rule.matches?(item)
        expect(result[:match]).to be false
      end
    end

    describe "keyword rule type" do
      it "matches single keyword in title" do
        rule = create(:tagging_rule, :keyword, taxonomy: taxonomy, site: site,
          pattern: "technology")
        result = rule.matches?(entry)
        expect(result[:match]).to be true
        expect(result[:confidence]).to be >= 0.7
        expect(result[:reason]).to include("Keywords matched")
      end

      it "matches multiple keywords (increases confidence)" do
        rule = create(:tagging_rule, :keyword, taxonomy: taxonomy, site: site,
          pattern: "technology, innovation, startup")
        result = rule.matches?(entry)
        expect(result[:match]).to be true
        # 0.7 + (0.1 * 3) = 1.0, but capped at 0.9
        expect(result[:confidence]).to eq(0.9)
      end

      it "is case insensitive" do
        rule = create(:tagging_rule, :keyword, taxonomy: taxonomy, site: site,
          pattern: "TECHNOLOGY")
        result = rule.matches?(entry)
        expect(result[:match]).to be true
      end

      it "searches in extracted_text and description" do
        item = create(:entry, :feed, site: site, source: source,
          title: "Random Title",
          extracted_text: "Contains innovation keyword",
          description: "Mentions startup")
        rule = create(:tagging_rule, :keyword, taxonomy: taxonomy, site: site,
          pattern: "innovation, startup")
        result = rule.matches?(item)
        expect(result[:match]).to be true
        expect(result[:confidence]).to be_within(0.001).of(0.9) # 0.7 + (0.1 * 2) = 0.9
      end

      it "does not match when no keywords found" do
        rule = create(:tagging_rule, :keyword, taxonomy: taxonomy, site: site,
          pattern: "blockchain, crypto")
        result = rule.matches?(entry)
        expect(result[:match]).to be false
      end

      it "handles blank text content" do
        # Pattern can't be empty due to validation, so test with valid pattern but blank content
        item = build(:entry, :feed, site: site, source: source,
          title: nil, extracted_text: nil, description: nil)
        rule = create(:tagging_rule, :keyword, taxonomy: taxonomy, site: site,
          pattern: "test")
        result = rule.matches?(item)
        expect(result[:match]).to be false
      end
    end

    describe "domain rule type" do
      it "matches exact domain" do
        rule = create(:tagging_rule, :domain, taxonomy: taxonomy, site: site,
          pattern: "example.com")
        result = rule.matches?(entry)
        expect(result[:match]).to be true
        expect(result[:confidence]).to eq(0.85)
        expect(result[:reason]).to include("Domain")
      end

      it "matches wildcard subdomain" do
        item = create(:entry, :feed, site: site, source: source,
          url_canonical: "https://blog.techcrunch.com/article")
        rule = create(:tagging_rule, :domain, taxonomy: taxonomy, site: site,
          pattern: "*.techcrunch.com")
        result = rule.matches?(item)
        expect(result[:match]).to be true
      end

      it "does not match different domain" do
        rule = create(:tagging_rule, :domain, taxonomy: taxonomy, site: site,
          pattern: "other.com")
        result = rule.matches?(entry)
        expect(result[:match]).to be false
      end

      it "handles invalid URL gracefully" do
        item = build(:entry, :feed, site: site, source: source,
          url_canonical: "not-a-valid-url")
        rule = create(:tagging_rule, :domain, taxonomy: taxonomy, site: site)
        result = rule.matches?(item)
        expect(result[:match]).to be false
      end

      it "handles blank URL" do
        item = build(:entry, :feed, site: site, source: source, url_canonical: "")
        rule = create(:tagging_rule, :domain, taxonomy: taxonomy, site: site)
        result = rule.matches?(item)
        expect(result[:match]).to be false
      end
    end
  end

  # Note: #set_tenant_from_site is tested in spec/models/concerns/site_scoped_spec.rb
end
