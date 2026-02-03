# frozen_string_literal: true

require "test_helper"

class AffiliateUrlServiceTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_affiliate") do |t|
      t.hostname = "affiliate-test.example.com"
      t.title = "Affiliate Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "affiliate-test.example.com"
    end

    @category = Category.find_or_create_by!(site: @site, tenant: @tenant, key: "tools") do |c|
      c.name = "Tools"
    end

    Current.tenant = @tenant
    Current.site = @site

    @listing = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Test Tool",
      url_raw: "https://example.com/tool",
      affiliate_url_template: "https://affiliate.example.com?url={url}&ref=curated"
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === URL Generation ===

  test "generates affiliate URL with url placeholder" do
    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    assert_includes url, "https://affiliate.example.com"
    assert_includes url, "url=https%3A%2F%2Fexample.com%2Ftool"
    assert_includes url, "ref=curated"
  end

  test "generates affiliate URL with title placeholder" do
    @listing.affiliate_url_template = "https://affiliate.example.com?title={title}"
    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    assert_includes url, "title=Test%20Tool"
  end

  test "generates affiliate URL with id placeholder" do
    @listing.affiliate_url_template = "https://affiliate.example.com?listing_id={id}"
    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    assert_includes url, "listing_id=#{@listing.id}"
  end

  test "generates affiliate URL with multiple placeholders" do
    @listing.affiliate_url_template = "https://affiliate.example.com?url={url}&title={title}&id={id}"
    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    assert_includes url, "url=https%3A%2F%2Fexample.com%2Ftool"
    assert_includes url, "title=Test%20Tool"
    assert_includes url, "id=#{@listing.id}"
  end

  test "returns nil when no template is set" do
    @listing.affiliate_url_template = nil
    service = AffiliateUrlService.new(@listing)

    assert_nil service.generate_url
  end

  test "returns nil when template is blank" do
    @listing.affiliate_url_template = ""
    service = AffiliateUrlService.new(@listing)

    assert_nil service.generate_url
  end

  # === Attribution Params ===

  test "applies attribution params to URL" do
    @listing.affiliate_url_template = "https://affiliate.example.com?url={url}"
    @listing.affiliate_attribution = { "campaign" => "spring", "source" => "curated" }

    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    assert_includes url, "campaign=spring"
    assert_includes url, "source=curated"
  end

  test "preserves existing params when adding attribution" do
    @listing.affiliate_url_template = "https://affiliate.example.com?url={url}&ref=base"
    @listing.affiliate_attribution = { "campaign" => "spring" }

    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    assert_includes url, "ref=base"
    assert_includes url, "campaign=spring"
  end

  test "handles empty attribution params" do
    @listing.affiliate_attribution = {}
    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    assert_includes url, "https://affiliate.example.com"
    assert_includes url, "ref=curated"
  end

  # === URL Encoding ===

  test "properly encodes special characters in URL" do
    @listing.url_canonical = "https://example.com/tool?param=value&other=test"
    @listing.affiliate_url_template = "https://affiliate.example.com?url={url}"

    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    # The canonical URL should be encoded
    assert_includes url, "url=https%3A%2F%2Fexample.com%2Ftool%3Fparam%3Dvalue%26other%3Dtest"
  end

  test "properly encodes special characters in title" do
    @listing.title = "Tool & Service <Test>"
    @listing.affiliate_url_template = "https://affiliate.example.com?title={title}"

    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    assert_includes url, "title=Tool%20%26%20Service%20%3CTest%3E"
  end

  # === Class Methods ===

  test "generate_url_for class method works" do
    url = AffiliateUrlService.generate_url_for(@listing)

    assert_includes url, "https://affiliate.example.com"
    assert_includes url, "ref=curated"
  end

  # === Click Tracking ===

  test "track_click creates affiliate click record" do
    request = OpenStruct.new(
      remote_ip: "192.168.1.1",
      user_agent: "Mozilla/5.0 Test Browser",
      referrer: "https://google.com"
    )

    service = AffiliateUrlService.new(@listing)

    assert_difference "AffiliateClick.count", 1 do
      click = service.track_click(request)

      assert_not_nil click
      assert_equal @listing, click.listing
      assert_not_nil click.clicked_at
      assert_not_nil click.ip_hash
      assert_equal "Mozilla/5.0 Test Browser", click.user_agent
      assert_equal "https://google.com", click.referrer
    end
  end

  test "track_click hashes IP for privacy" do
    request = OpenStruct.new(
      remote_ip: "192.168.1.1",
      user_agent: "Test",
      referrer: nil
    )

    service = AffiliateUrlService.new(@listing)
    click = service.track_click(request)

    # IP hash should not contain the original IP
    assert_not_equal "192.168.1.1", click.ip_hash
    # IP hash should be truncated to 16 characters
    assert_equal 16, click.ip_hash.length
  end

  test "track_click truncates long user agent" do
    long_user_agent = "A" * 500
    request = OpenStruct.new(
      remote_ip: "192.168.1.1",
      user_agent: long_user_agent,
      referrer: nil
    )

    service = AffiliateUrlService.new(@listing)
    click = service.track_click(request)

    assert click.user_agent.length <= 255
  end

  test "track_click returns nil for non-persisted listing" do
    new_listing = Listing.new(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "New Tool",
      url_raw: "https://example.com/new"
    )

    request = OpenStruct.new(
      remote_ip: "192.168.1.1",
      user_agent: "Test",
      referrer: nil
    )

    service = AffiliateUrlService.new(new_listing)
    assert_nil service.track_click(request)
  end

  test "track_click_for class method works" do
    request = OpenStruct.new(
      remote_ip: "192.168.1.1",
      user_agent: "Test",
      referrer: nil
    )

    assert_difference "AffiliateClick.count", 1 do
      AffiliateUrlService.track_click_for(@listing, request)
    end
  end

  # === Edge Cases ===

  test "handles nil title gracefully" do
    @listing.title = nil
    @listing.affiliate_url_template = "https://affiliate.example.com?title={title}"

    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    assert_includes url, "title="
  end

  test "handles nil url_canonical gracefully" do
    # Save first, then modify to test edge case
    @listing.affiliate_url_template = "https://affiliate.example.com?url={url}"
    @listing.instance_variable_set(:@url_canonical, nil)

    service = AffiliateUrlService.new(@listing)
    url = service.generate_url

    # Should still generate a URL, just with empty url param
    assert_includes url, "https://affiliate.example.com"
  end
end
