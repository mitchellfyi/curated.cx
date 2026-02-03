# frozen_string_literal: true

require "test_helper"

class ContentItemTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_content") do |t|
      t.hostname = "content-test.example.com"
      t.title = "Content Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "content-test.example.com"
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

    @content_item = ContentItem.new(
      site: @site,
      source: @source,
      url_raw: "https://example.com/article",
      url_canonical: "https://example.com/article",
      title: "Test Article",
      description: "A test article description",
      raw_payload: { "title" => "Test Article" },
      tags: ["tech", "news"]
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @content_item.valid?, @content_item.errors.full_messages.join(", ")
  end

  test "should require url_canonical" do
    @content_item.url_canonical = nil
    assert_not @content_item.valid?
    assert_includes @content_item.errors[:url_canonical], "can't be blank"
  end

  test "should require url_raw" do
    @content_item.url_raw = nil
    assert_not @content_item.valid?
    assert_includes @content_item.errors[:url_raw], "can't be blank"
  end

  test "should require raw_payload" do
    @content_item.raw_payload = nil
    assert_not @content_item.valid?
    assert_includes @content_item.errors[:raw_payload], "can't be blank"
  end

  test "should require unique url_canonical per site" do
    @content_item.save!
    duplicate = ContentItem.new(
      site: @site,
      source: @source,
      url_raw: "https://example.com/article",
      url_canonical: "https://example.com/article",  # Same URL
      raw_payload: { "title" => "Duplicate" },
      tags: []
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:url_canonical], "has already been taken"
  end

  # === Published Status ===

  test "should not be published by default" do
    assert_not @content_item.published?
  end

  test "should be published when published_at is set" do
    @content_item.published_at = Time.current
    assert @content_item.published?
  end

  test "published scope returns only published items" do
    @content_item.save!

    published = ContentItem.create!(
      site: @site,
      source: @source,
      url_raw: "https://example.com/published",
      url_canonical: "https://example.com/published",
      raw_payload: {},
      tags: [],
      published_at: Time.current
    )

    results = ContentItem.published
    assert_includes results, published
    assert_not_includes results, @content_item
  end

  # === Scheduling ===

  test "should not be scheduled by default" do
    assert_not @content_item.scheduled?
  end

  test "should be scheduled when scheduled_for is in the future" do
    @content_item.scheduled_for = 1.day.from_now
    assert @content_item.scheduled?
  end

  test "should not be scheduled when scheduled_for is in the past" do
    @content_item.scheduled_for = 1.day.ago
    assert_not @content_item.scheduled?
  end

  # === Hidden Status ===

  test "should not be hidden by default" do
    assert_not @content_item.hidden?
  end

  test "should be hidden when hidden_at is set" do
    @content_item.hidden_at = Time.current
    assert @content_item.hidden?
  end

  test "hide! sets hidden_at and hidden_by" do
    user = User.create!(
      email: "test-hide@example.com",
      password: "password123"
    )
    @content_item.save!
    @content_item.hide!(user)

    assert @content_item.hidden?
    assert_equal user, @content_item.hidden_by
  end

  test "unhide! clears hidden_at and hidden_by" do
    user = User.create!(
      email: "test-unhide@example.com",
      password: "password123"
    )
    @content_item.save!
    @content_item.hide!(user)
    @content_item.unhide!

    assert_not @content_item.hidden?
    assert_nil @content_item.hidden_by
  end

  # === Comments Locking ===

  test "should not have comments locked by default" do
    assert_not @content_item.comments_locked?
  end

  test "lock_comments! sets comments_locked_at" do
    user = User.create!(
      email: "test-lock@example.com",
      password: "password123"
    )
    @content_item.save!
    @content_item.lock_comments!(user)

    assert @content_item.comments_locked?
    assert_equal user, @content_item.comments_locked_by
  end

  test "unlock_comments! clears comments_locked_at" do
    user = User.create!(
      email: "test-unlock@example.com",
      password: "password123"
    )
    @content_item.save!
    @content_item.lock_comments!(user)
    @content_item.unlock_comments!

    assert_not @content_item.comments_locked?
    assert_nil @content_item.comments_locked_by
  end

  # === Editorialisation ===

  test "should not be editorialised by default" do
    assert_not @content_item.editorialised?
  end

  test "should be editorialised when editorialised_at is set" do
    @content_item.editorialised_at = Time.current
    assert @content_item.editorialised?
  end

  # === Default Values ===

  test "raw_payload returns empty hash by default" do
    item = ContentItem.new
    assert_equal({}, item.raw_payload)
  end

  test "tags returns empty array by default" do
    item = ContentItem.new
    assert_equal [], item.tags
  end

  test "topic_tags returns empty array by default" do
    item = ContentItem.new
    assert_equal [], item.topic_tags
  end

  test "ai_suggested_tags returns empty array by default" do
    item = ContentItem.new
    assert_equal [], item.ai_suggested_tags
  end

  test "tagging_explanation returns empty array by default" do
    item = ContentItem.new
    assert_equal [], item.tagging_explanation
  end

  # === Scopes ===

  test "recent scope orders by created_at desc" do
    @content_item.save!

    newer = ContentItem.create!(
      site: @site,
      source: @source,
      url_raw: "https://example.com/newer",
      url_canonical: "https://example.com/newer",
      raw_payload: {},
      tags: []
    )

    results = ContentItem.recent.limit(2)
    assert_equal newer, results.first
  end

  test "by_source scope filters by source" do
    @content_item.save!

    other_source = Source.create!(
      site: @site,
      tenant: @tenant,
      name: "Other Feed",
      kind: :rss,
      feed_url: "https://other.com/feed.xml"
    )

    other_item = ContentItem.create!(
      site: @site,
      source: other_source,
      url_raw: "https://other.com/article",
      url_canonical: "https://other.com/article",
      raw_payload: {},
      tags: []
    )

    results = ContentItem.by_source(@source)
    assert_includes results, @content_item
    assert_not_includes results, other_item
  end

  test "not_hidden scope excludes hidden items" do
    @content_item.save!

    hidden = ContentItem.create!(
      site: @site,
      source: @source,
      url_raw: "https://example.com/hidden",
      url_canonical: "https://example.com/hidden",
      raw_payload: {},
      tags: [],
      hidden_at: Time.current
    )

    results = ContentItem.not_hidden
    assert_includes results, @content_item
    assert_not_includes results, hidden
  end

  # === Class Methods ===

  test "find_or_initialize_by_canonical_url finds existing item" do
    @content_item.save!

    found = ContentItem.find_or_initialize_by_canonical_url(
      site: @site,
      url_canonical: "https://example.com/article",
      source: @source
    )

    assert_equal @content_item, found
    assert found.persisted?
  end

  test "find_or_initialize_by_canonical_url initializes new item" do
    item = ContentItem.find_or_initialize_by_canonical_url(
      site: @site,
      url_canonical: "https://example.com/new-article",
      source: @source
    )

    assert_not item.persisted?
    assert_equal @source, item.source
    assert_equal "https://example.com/new-article", item.url_canonical
  end

  # === URL Normalization ===

  test "normalizes url_canonical on save" do
    @content_item.url_canonical = "https://EXAMPLE.COM/ARTICLE?utm_source=test"
    @content_item.save!

    assert_equal "https://example.com/ARTICLE", @content_item.url_canonical
  end

  # === Delegation ===

  test "delegates site_name" do
    @content_item.save!
    assert_equal "Test Site", @content_item.site_name
  end

  test "delegates source_name" do
    @content_item.save!
    assert_equal "Test Feed", @content_item.source_name
  end
end
