# frozen_string_literal: true

require "test_helper"

class SourceTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_source") do |t|
      t.hostname = "source-test.example.com"
      t.title = "Source Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "source-test.example.com"
    end

    Current.tenant = @tenant
    Current.site = @site

    @source = Source.new(
      tenant: @tenant,
      site: @site,
      name: "Test RSS Feed",
      kind: :rss,
      config: { "feed_url" => "https://example.com/feed.xml" }
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @source.valid?, @source.errors.full_messages.join(", ")
  end

  test "should require name" do
    @source.name = nil
    assert_not @source.valid?
    assert_includes @source.errors[:name], "can't be blank"
  end

  test "should require kind" do
    @source.kind = nil
    assert_not @source.valid?
    assert_includes @source.errors[:kind], "can't be blank"
  end

  test "should require unique name per site" do
    @source.save!
    duplicate = Source.new(
      tenant: @tenant,
      site: @site,
      name: "Test RSS Feed",  # Same name
      kind: :api
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name in different sites" do
    @source.save!

    other_site = Site.create!(
      tenant: @tenant,
      name: "Other Site",
      slug: "other_site_source"
    )

    other_source = Source.new(
      tenant: @tenant,
      site: other_site,
      name: "Test RSS Feed",  # Same name, different site
      kind: :rss
    )

    Current.site = other_site
    assert other_source.valid?, other_source.errors.full_messages.join(", ")
  end

  test "should validate quality_weight range" do
    @source.quality_weight = -0.1
    assert_not @source.valid?

    @source.quality_weight = 2.1
    assert_not @source.valid?

    @source.quality_weight = 1.5
    assert @source.valid?
  end

  # === Kind Enum ===

  test "should have rss kind" do
    @source.kind = :rss
    assert @source.rss?
  end

  test "should have api kind" do
    @source.kind = :api
    assert @source.api?
  end

  test "should have web_scraper kind" do
    @source.kind = :web_scraper
    assert @source.web_scraper?
  end

  test "should have serp_api_google_news kind" do
    @source.kind = :serp_api_google_news
    assert @source.serp_api_google_news?
  end

  test "should have serp_api_google_jobs kind" do
    @source.kind = :serp_api_google_jobs
    assert @source.serp_api_google_jobs?
  end

  # === Enabled Status ===

  test "should be enabled by default" do
    source = Source.new
    assert source.enabled?
  end

  # === Scopes ===

  test "enabled scope returns only enabled sources" do
    @source.enabled = true
    @source.save!

    disabled = Source.create!(
      tenant: @tenant,
      site: @site,
      name: "Disabled Feed",
      kind: :rss,
      enabled: false
    )

    results = Source.enabled
    assert_includes results, @source
    assert_not_includes results, disabled
  end

  test "disabled scope returns only disabled sources" do
    @source.enabled = true
    @source.save!

    disabled = Source.create!(
      tenant: @tenant,
      site: @site,
      name: "Disabled Feed",
      kind: :rss,
      enabled: false
    )

    results = Source.disabled
    assert_not_includes results, @source
    assert_includes results, disabled
  end

  test "by_kind scope filters by kind" do
    @source.kind = :rss
    @source.save!

    api_source = Source.create!(
      tenant: @tenant,
      site: @site,
      name: "API Source",
      kind: :api
    )

    results = Source.by_kind(:rss)
    assert_includes results, @source
    assert_not_includes results, api_source
  end

  # === Config ===

  test "config returns empty hash by default" do
    source = Source.new
    assert_equal({}, source.config)
  end

  test "should validate config is a hash" do
    @source.config = "not a hash"
    assert_not @source.valid?
    assert_includes @source.errors[:config], "must be a valid JSON object"
  end

  # === Schedule ===

  test "schedule returns empty hash by default" do
    source = Source.new
    assert_equal({}, source.schedule)
  end

  test "should validate schedule is a hash" do
    @source.schedule = "not a hash"
    assert_not @source.valid?
    assert_includes @source.errors[:schedule], "must be a valid JSON object"
  end

  test "schedule_interval_seconds returns configured interval" do
    @source.schedule = { "interval_seconds" => 3600 }
    assert_equal 3600, @source.schedule_interval_seconds
  end

  test "schedule_interval_seconds handles symbol keys" do
    @source.schedule = { interval_seconds: 7200 }
    assert_equal 7200, @source.schedule_interval_seconds
  end

  test "schedule_interval_seconds returns nil when not set" do
    @source.schedule = {}
    assert_nil @source.schedule_interval_seconds
  end

  # === Run Due ===

  test "run_due? returns true when never run" do
    @source.last_run_at = nil
    @source.schedule = { "interval_seconds" => 3600 }
    assert @source.run_due?
  end

  test "run_due? returns false when disabled" do
    @source.enabled = false
    @source.last_run_at = 2.hours.ago
    @source.schedule = { "interval_seconds" => 3600 }
    assert_not @source.run_due?
  end

  test "run_due? returns true when past interval" do
    @source.enabled = true
    @source.last_run_at = 2.hours.ago
    @source.schedule = { "interval_seconds" => 3600 }  # 1 hour
    assert @source.run_due?
  end

  test "run_due? returns false when within interval" do
    @source.enabled = true
    @source.last_run_at = 30.minutes.ago
    @source.schedule = { "interval_seconds" => 3600 }  # 1 hour
    assert_not @source.run_due?
  end

  # === Update Run Status ===

  test "update_run_status updates last_run_at and last_status" do
    @source.save!

    @source.update_run_status(:success)
    @source.reload

    assert_not_nil @source.last_run_at
    assert_equal "success", @source.last_status
  end

  # === Editorialisation ===

  test "editorialisation_enabled? returns false by default" do
    assert_not @source.editorialisation_enabled?
  end

  test "editorialisation_enabled? returns true when enabled in config" do
    @source.config = { "editorialise" => true }
    assert @source.editorialisation_enabled?
  end

  test "editorialisation_enabled? handles symbol keys" do
    @source.config = { editorialise: true }
    assert @source.editorialisation_enabled?
  end

  # === Associations ===

  test "has many listings" do
    @source.save!

    category = Category.create!(
      tenant: @tenant,
      site: @site,
      name: "Test",
      key: "test_src"
    )

    listing = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: category,
      source: @source,
      title: "Test Listing",
      url_raw: "https://example.com/listing"
    )

    assert_includes @source.listings, listing
  end

  test "has many content_items" do
    @source.save!

    content_item = ContentItem.create!(
      site: @site,
      source: @source,
      url_raw: "https://example.com/content",
      url_canonical: "https://example.com/content",
      raw_payload: {},
      tags: []
    )

    assert_includes @source.content_items, content_item
  end

  test "has many import_runs" do
    @source.save!

    import_run = ImportRun.create!(
      source: @source,
      site: @site,
      started_at: Time.current
    )

    assert_includes @source.import_runs, import_run
  end
end
