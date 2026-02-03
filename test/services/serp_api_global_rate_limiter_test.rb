# frozen_string_literal: true

require "test_helper"

class SerpApiGlobalRateLimiterTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_serp_limit") do |t|
      t.hostname = "serp-limit-test.example.com"
      t.title = "SerpAPI Limit Test"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "serp-limit-test.example.com"
    end

    @source = Source.find_or_create_by!(
      site: @site,
      tenant: @tenant,
      name: "SerpAPI News Source",
      kind: :serp_api_google_news
    ) do |s|
      s.config = { "api_key" => "test_key", "query" => "AI news" }
    end

    Current.tenant = @tenant
    Current.site = @site

    # Clean up any existing import runs for our test source
    ImportRun.where(source: @source).delete_all
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === allow? ===

  test "allow? returns true when under monthly limit" do
    assert SerpApiGlobalRateLimiter.allow?
  end

  test "allow? returns false when at monthly limit" do
    # Create enough import runs to hit the limit
    limit = SerpApiGlobalRateLimiter::MONTHLY_LIMIT
    limit.times do
      ImportRun.create!(
        source: @source,
        site: @site,
        started_at: Time.current
      )
    end

    assert_not SerpApiGlobalRateLimiter.allow?
  end

  # === allow_today? ===

  test "allow_today? returns true when under daily limit" do
    assert SerpApiGlobalRateLimiter.allow_today?
  end

  test "allow_today? returns false when at daily limit" do
    limit = SerpApiGlobalRateLimiter::DAILY_SOFT_LIMIT
    limit.times do
      ImportRun.create!(
        source: @source,
        site: @site,
        started_at: Time.current
      )
    end

    assert_not SerpApiGlobalRateLimiter.allow_today?
  end

  # === can_make_request? ===

  test "can_make_request? returns true when under both limits" do
    assert SerpApiGlobalRateLimiter.can_make_request?
  end

  # === monthly_used ===

  test "monthly_used counts import runs this month" do
    # Create some runs this month
    3.times do
      ImportRun.create!(
        source: @source,
        site: @site,
        started_at: Time.current
      )
    end

    assert_equal 3, SerpApiGlobalRateLimiter.monthly_used
  end

  test "monthly_used ignores runs from previous months" do
    # Create run from last month (skip callbacks to avoid validation)
    ImportRun.create!(
      source: @source,
      site: @site,
      started_at: 2.months.ago
    )

    # Create run this month
    ImportRun.create!(
      source: @source,
      site: @site,
      started_at: Time.current
    )

    assert_equal 1, SerpApiGlobalRateLimiter.monthly_used
  end

  # === daily_used ===

  test "daily_used counts import runs today" do
    # Create runs today
    2.times do
      ImportRun.create!(
        source: @source,
        site: @site,
        started_at: Time.current
      )
    end

    assert_equal 2, SerpApiGlobalRateLimiter.daily_used
  end

  test "daily_used ignores runs from yesterday" do
    # Create run from yesterday
    ImportRun.create!(
      source: @source,
      site: @site,
      started_at: 1.day.ago.beginning_of_day + 12.hours
    )

    # Create run today
    ImportRun.create!(
      source: @source,
      site: @site,
      started_at: Time.current
    )

    assert_equal 1, SerpApiGlobalRateLimiter.daily_used
  end

  # === Only counts SerpAPI sources ===

  test "only counts SerpAPI source types" do
    # Create RSS source (should not be counted)
    rss_source = Source.create!(
      site: @site,
      tenant: @tenant,
      name: "RSS Source",
      kind: :rss,
      config: { "feed_url" => "https://example.com/feed.xml" }
    )

    # Create run for RSS source
    ImportRun.create!(
      source: rss_source,
      site: @site,
      started_at: Time.current
    )

    # Create run for SerpAPI source
    ImportRun.create!(
      source: @source,
      site: @site,
      started_at: Time.current
    )

    # Should only count the SerpAPI run
    assert_equal 1, SerpApiGlobalRateLimiter.monthly_used
  end

  test "counts both serp_api_google_news and serp_api_google_jobs" do
    # Create jobs source
    jobs_source = Source.create!(
      site: @site,
      tenant: @tenant,
      name: "SerpAPI Jobs Source",
      kind: :serp_api_google_jobs,
      config: { "api_key" => "test_key", "query" => "developer jobs" }
    )

    # Create run for news source
    ImportRun.create!(
      source: @source,
      site: @site,
      started_at: Time.current
    )

    # Create run for jobs source
    ImportRun.create!(
      source: jobs_source,
      site: @site,
      started_at: Time.current
    )

    assert_equal 2, SerpApiGlobalRateLimiter.monthly_used
  end

  # === usage_stats ===

  test "usage_stats returns expected structure" do
    stats = SerpApiGlobalRateLimiter.usage_stats

    assert stats.key?(:monthly)
    assert stats.key?(:daily)
    assert stats.key?(:projections)

    assert stats[:monthly].key?(:used)
    assert stats[:monthly].key?(:limit)
    assert stats[:monthly].key?(:remaining)
    assert stats[:monthly].key?(:percent_used)

    assert stats[:daily].key?(:used)
    assert stats[:daily].key?(:soft_limit)
    assert stats[:daily].key?(:remaining)

    assert stats[:projections].key?(:projected_monthly_total)
    assert stats[:projections].key?(:on_track)
  end

  # === check! ===

  test "check! raises when monthly limit exceeded" do
    limit = SerpApiGlobalRateLimiter::MONTHLY_LIMIT
    limit.times do
      ImportRun.create!(
        source: @source,
        site: @site,
        started_at: Time.current
      )
    end

    assert_raises(SerpApiGlobalRateLimiter::RateLimitExceeded) do
      SerpApiGlobalRateLimiter.check!
    end
  end

  test "check! returns true when under limit" do
    assert SerpApiGlobalRateLimiter.check!
  end

  # === Cross-tenant counting ===

  test "counts usage across all tenants" do
    # Create another tenant and site
    other_tenant = Tenant.create!(
      hostname: "other-serp.example.com",
      slug: "other_serp",
      title: "Other Tenant"
    )

    other_site = Site.create!(
      tenant: other_tenant,
      name: "Other Site",
      slug: "other_serp_site"
    )

    other_source = Source.create!(
      site: other_site,
      tenant: other_tenant,
      name: "Other SerpAPI Source",
      kind: :serp_api_google_news,
      config: { "api_key" => "test_key" }
    )

    # Create runs from both tenants
    ImportRun.create!(source: @source, site: @site, started_at: Time.current)
    ImportRun.create!(source: other_source, site: other_site, started_at: Time.current)

    # Should count both
    assert_equal 2, SerpApiGlobalRateLimiter.monthly_used
  end
end
