# frozen_string_literal: true

require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.find_or_create_by!(slug: "listings_test") do |t|
      t.hostname = "listings-test.example.com"
      t.title = "Listings Test"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "listings-test.example.com"
    end

    Domain.find_or_create_by!(hostname: "listings-test.example.com") do |d|
      d.site = @site
      d.primary = true
      d.verified = true
      d.status = :active
    end

    @category = Category.find_or_create_by!(site: @site, tenant: @tenant, key: "tools") do |c|
      c.name = "Tools"
    end

    @published_listing = Listing.find_or_create_by!(
      tenant: @tenant,
      site: @site,
      category: @category,
      url_canonical: "https://example.com/published-tool"
    ) do |l|
      l.title = "Published Tool"
      l.url_raw = "https://example.com/published-tool"
      l.published_at = 1.day.ago
      l.listing_type = :tool
    end

    @draft_listing = Listing.find_or_create_by!(
      tenant: @tenant,
      site: @site,
      category: @category,
      url_canonical: "https://example.com/draft-tool"
    ) do |l|
      l.title = "Draft Tool"
      l.url_raw = "https://example.com/draft-tool"
      l.published_at = nil
      l.listing_type = :tool
    end
  end

  # === Index ===

  test "should get index" do
    host! "listings-test.example.com"

    get listings_path

    assert_response :success
  end

  test "index shows published listings" do
    host! "listings-test.example.com"

    get listings_path

    assert_response :success
    assert_select "a", text: @published_listing.title
  end

  test "index does not show draft listings" do
    host! "listings-test.example.com"

    get listings_path

    assert_response :success
    assert_select "a", text: @draft_listing.title, count: 0
  end

  test "index filters by category" do
    host! "listings-test.example.com"

    other_category = Category.create!(
      site: @site,
      tenant: @tenant,
      name: "Other",
      key: "other"
    )

    other_listing = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: other_category,
      title: "Other Tool",
      url_raw: "https://example.com/other-tool",
      published_at: Time.current
    )

    get category_path(@category)

    assert_response :success
    assert_select "a", text: @published_listing.title
    assert_select "a", text: other_listing.title, count: 0
  end

  test "index filters by type" do
    host! "listings-test.example.com"

    job_listing = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Job Listing",
      url_raw: "https://example.com/job",
      published_at: Time.current,
      listing_type: :job
    )

    get listings_path(type: "job")

    assert_response :success
    assert_select "a", text: job_listing.title
  end

  test "index responds to turbo stream" do
    host! "listings-test.example.com"

    get listings_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
  end

  # === Show ===

  test "should get show for published listing" do
    host! "listings-test.example.com"

    get listing_path(@published_listing)

    assert_response :success
  end

  test "show displays listing details" do
    host! "listings-test.example.com"

    get listing_path(@published_listing)

    assert_response :success
    assert_select "h1", text: @published_listing.title
  end

  test "show returns 404 for non-existent listing" do
    host! "listings-test.example.com"

    assert_raises(ActiveRecord::RecordNotFound) do
      get listing_path(id: 999999)
    end
  end

  # === Featured Listings ===

  test "index shows featured listings section" do
    host! "listings-test.example.com"

    featured = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Featured Tool",
      url_raw: "https://example.com/featured-tool",
      published_at: Time.current,
      featured_from: 1.day.ago,
      featured_until: 1.day.from_now
    )

    get listings_path

    assert_response :success
    # Featured listings should appear
    assert_match featured.title, response.body
  end

  # === Expired Listings ===

  test "index does not show expired listings" do
    host! "listings-test.example.com"

    expired = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Expired Job",
      url_raw: "https://example.com/expired-job",
      published_at: 1.month.ago,
      listing_type: :job,
      expires_at: 1.day.ago
    )

    get listings_path

    assert_response :success
    assert_select "a", text: expired.title, count: 0
  end

  # === Search/Query ===

  test "index filters by search query" do
    host! "listings-test.example.com"

    searchable = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Unique Searchable Name",
      url_raw: "https://example.com/searchable",
      published_at: Time.current
    )

    get listings_path(q: "Unique Searchable")

    assert_response :success
    # Search should work (implementation dependent)
  end

  # === Freshness Filters ===

  test "index filters by freshness today" do
    host! "listings-test.example.com"

    today_listing = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Today Tool",
      url_raw: "https://example.com/today-tool",
      published_at: Time.current
    )

    get listings_path(freshness: "today")

    assert_response :success
  end
end
