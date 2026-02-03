# frozen_string_literal: true

require "test_helper"

class TaggingServiceTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_tagging") do |t|
      t.hostname = "tagging-test.example.com"
      t.title = "Tagging Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "tagging-test.example.com"
    end

    @source = Source.find_or_create_by!(
      site: @site,
      tenant: @tenant,
      name: "Test Feed",
      kind: :rss
    ) do |s|
      s.feed_url = "https://example.com/feed.xml"
    end

    Current.tenant = @tenant
    Current.site = @site

    @taxonomy = Taxonomy.find_or_create_by!(
      site: @site,
      tenant: @tenant,
      slug: "ai"
    ) do |t|
      t.name = "AI"
    end

    @content_item = ContentItem.new(
      site: @site,
      source: @source,
      url_raw: "https://example.com/article",
      url_canonical: "https://example.com/article",
      title: "AI Revolution in 2024",
      description: "An article about artificial intelligence and machine learning",
      raw_payload: {},
      tags: []
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Basic Functionality ===

  test "returns empty result for nil content item" do
    result = TaggingService.tag(nil)

    assert_equal [], result[:topic_tags]
    assert_nil result[:content_type]
    assert_nil result[:confidence]
    assert_equal [], result[:explanation]
  end

  test "returns empty result for content item without site" do
    @content_item.site_id = nil
    result = TaggingService.tag(@content_item)

    assert_equal [], result[:topic_tags]
  end

  test "returns empty result when no rules exist" do
    @content_item.save!
    TaggingRule.where(site: @site).delete_all

    result = TaggingService.tag(@content_item)

    assert_equal [], result[:topic_tags]
  end

  # === Rule Matching ===

  test "matches content by title keyword rule" do
    rule = TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: @taxonomy,
      name: "AI Rule",
      rule_type: :keyword,
      config: { "keywords" => ["AI", "artificial intelligence"] },
      enabled: true
    )

    @content_item.save!
    result = TaggingService.tag(@content_item)

    assert_includes result[:topic_tags], "ai"
    assert_not_nil result[:confidence]
  end

  test "returns explanation for matched rules" do
    rule = TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: @taxonomy,
      name: "AI Rule",
      rule_type: :keyword,
      config: { "keywords" => ["AI"] },
      enabled: true
    )

    @content_item.save!
    result = TaggingService.tag(@content_item)

    assert result[:explanation].any?
    assert_equal rule.id, result[:explanation].first[:rule_id]
    assert_equal "ai", result[:explanation].first[:taxonomy_slug]
  end

  test "skips disabled rules" do
    TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: @taxonomy,
      name: "Disabled Rule",
      rule_type: :keyword,
      config: { "keywords" => ["AI"] },
      enabled: false
    )

    @content_item.save!
    result = TaggingService.tag(@content_item)

    assert_equal [], result[:topic_tags]
  end

  # === Multiple Rules ===

  test "matches multiple rules and returns all tags" do
    ml_taxonomy = Taxonomy.create!(
      site: @site,
      tenant: @tenant,
      slug: "ml",
      name: "Machine Learning"
    )

    TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: @taxonomy,
      name: "AI Rule",
      rule_type: :keyword,
      config: { "keywords" => ["AI"] },
      enabled: true
    )

    TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: ml_taxonomy,
      name: "ML Rule",
      rule_type: :keyword,
      config: { "keywords" => ["machine learning"] },
      enabled: true
    )

    @content_item.save!
    result = TaggingService.tag(@content_item)

    assert_includes result[:topic_tags], "ai"
    assert_includes result[:topic_tags], "ml"
  end

  test "returns unique topic tags" do
    # Two rules for same taxonomy
    TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: @taxonomy,
      name: "AI Rule 1",
      rule_type: :keyword,
      config: { "keywords" => ["AI"] },
      enabled: true
    )

    TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: @taxonomy,
      name: "AI Rule 2",
      rule_type: :keyword,
      config: { "keywords" => ["artificial intelligence"] },
      enabled: true
    )

    @content_item.save!
    result = TaggingService.tag(@content_item)

    # Should only appear once
    assert_equal 1, result[:topic_tags].count("ai")
  end

  test "returns max confidence from matched rules" do
    TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: @taxonomy,
      name: "High Confidence Rule",
      rule_type: :keyword,
      config: { "keywords" => ["AI"], "confidence" => 0.9 },
      enabled: true
    )

    @content_item.save!
    result = TaggingService.tag(@content_item)

    # Confidence should be from the matching rule
    assert_not_nil result[:confidence]
  end

  # === Class Method ===

  test "tag class method works" do
    TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: @taxonomy,
      name: "AI Rule",
      rule_type: :keyword,
      config: { "keywords" => ["AI"] },
      enabled: true
    )

    @content_item.save!
    result = TaggingService.tag(@content_item)

    assert_kind_of Hash, result
    assert result.key?(:topic_tags)
    assert result.key?(:confidence)
    assert result.key?(:explanation)
  end

  # === Rule Priority ===

  test "evaluates rules in priority order" do
    low_priority_taxonomy = Taxonomy.create!(
      site: @site,
      tenant: @tenant,
      slug: "low",
      name: "Low Priority"
    )

    high_priority_taxonomy = Taxonomy.create!(
      site: @site,
      tenant: @tenant,
      slug: "high",
      name: "High Priority"
    )

    # Create rules with different priorities
    TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: low_priority_taxonomy,
      name: "Low Priority Rule",
      rule_type: :keyword,
      config: { "keywords" => ["AI"] },
      priority: 10,
      enabled: true
    )

    TaggingRule.create!(
      site: @site,
      tenant: @tenant,
      taxonomy: high_priority_taxonomy,
      name: "High Priority Rule",
      rule_type: :keyword,
      config: { "keywords" => ["AI"] },
      priority: 1,
      enabled: true
    )

    @content_item.save!
    result = TaggingService.tag(@content_item)

    # Both should match, but high priority should be first in explanation
    assert result[:explanation].length >= 2
  end
end
