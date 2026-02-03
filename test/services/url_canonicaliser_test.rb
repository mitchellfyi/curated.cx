# frozen_string_literal: true

require "test_helper"

class UrlCanonicaliserTest < ActiveSupport::TestCase
  # === Basic Canonicalization ===

  test "canonicalizes a simple URL" do
    result = UrlCanonicaliser.canonicalize("https://example.com")
    assert_equal "https://example.com", result
  end

  test "lowercases the scheme" do
    result = UrlCanonicaliser.canonicalize("HTTPS://example.com")
    assert_equal "https://example.com", result
  end

  test "lowercases the host" do
    result = UrlCanonicaliser.canonicalize("https://EXAMPLE.COM/path")
    assert_equal "https://example.com/path", result
  end

  test "preserves path case" do
    result = UrlCanonicaliser.canonicalize("https://example.com/Path/To/Page")
    assert_equal "https://example.com/Path/To/Page", result
  end

  test "removes trailing slashes from paths" do
    result = UrlCanonicaliser.canonicalize("https://example.com/path/")
    assert_equal "https://example.com/path", result
  end

  test "keeps trailing slash for root path" do
    result = UrlCanonicaliser.canonicalize("https://example.com/")
    assert_equal "https://example.com/", result
  end

  test "handles URLs without paths" do
    result = UrlCanonicaliser.canonicalize("https://example.com")
    assert_equal "https://example.com", result
  end

  # === Tracking Parameters ===

  test "removes utm_source parameter" do
    result = UrlCanonicaliser.canonicalize("https://example.com?utm_source=google")
    assert_equal "https://example.com", result
  end

  test "removes utm_medium parameter" do
    result = UrlCanonicaliser.canonicalize("https://example.com?utm_medium=cpc")
    assert_equal "https://example.com", result
  end

  test "removes utm_campaign parameter" do
    result = UrlCanonicaliser.canonicalize("https://example.com?utm_campaign=spring")
    assert_equal "https://example.com", result
  end

  test "removes fbclid parameter" do
    result = UrlCanonicaliser.canonicalize("https://example.com?fbclid=abc123")
    assert_equal "https://example.com", result
  end

  test "removes gclid parameter" do
    result = UrlCanonicaliser.canonicalize("https://example.com?gclid=xyz789")
    assert_equal "https://example.com", result
  end

  test "removes ref parameter" do
    result = UrlCanonicaliser.canonicalize("https://example.com?ref=affiliate")
    assert_equal "https://example.com", result
  end

  test "removes multiple tracking parameters" do
    url = "https://example.com?utm_source=google&utm_medium=cpc&utm_campaign=spring&fbclid=abc"
    result = UrlCanonicaliser.canonicalize(url)
    assert_equal "https://example.com", result
  end

  test "preserves non-tracking parameters" do
    result = UrlCanonicaliser.canonicalize("https://example.com?page=2&sort=date")
    assert_includes result, "page=2"
    assert_includes result, "sort=date"
  end

  test "removes tracking but keeps non-tracking parameters" do
    url = "https://example.com?page=2&utm_source=google&sort=date"
    result = UrlCanonicaliser.canonicalize(url)
    assert_includes result, "page=2"
    assert_includes result, "sort=date"
    assert_not_includes result, "utm_source"
  end

  # === Canonical Link Extraction ===

  test "extracts canonical URL from HTML" do
    html = '<html><head><link rel="canonical" href="https://example.com/canonical-page"></head></html>'
    result = UrlCanonicaliser.canonicalize("https://example.com/page?ref=123", html_content: html)
    assert_equal "https://example.com/canonical-page", result
  end

  test "handles relative canonical URL" do
    html = '<html><head><link rel="canonical" href="/canonical-page"></head></html>'
    result = UrlCanonicaliser.canonicalize("https://example.com/page", html_content: html)
    assert_equal "https://example.com/canonical-page", result
  end

  test "handles canonical with double quotes" do
    html = '<link rel="canonical" href="https://example.com/page">'
    result = UrlCanonicaliser.canonicalize("https://other.com", html_content: html)
    assert_equal "https://example.com/page", result
  end

  test "handles canonical with single quotes" do
    html = "<link rel='canonical' href='https://example.com/page'>"
    result = UrlCanonicaliser.canonicalize("https://other.com", html_content: html)
    assert_equal "https://example.com/page", result
  end

  test "uses original URL when no canonical in HTML" do
    html = "<html><head><title>Test</title></head></html>"
    result = UrlCanonicaliser.canonicalize("https://example.com/page", html_content: html)
    assert_equal "https://example.com/page", result
  end

  # === Error Handling ===

  test "returns nil for blank URL" do
    assert_nil UrlCanonicaliser.canonicalize("")
    assert_nil UrlCanonicaliser.canonicalize(nil)
    assert_nil UrlCanonicaliser.canonicalize("   ")
  end

  test "raises error for invalid URL" do
    assert_raises(UrlCanonicaliser::InvalidUrlError) do
      UrlCanonicaliser.canonicalize("not-a-url")
    end
  end

  test "raises error for non-HTTP URL" do
    assert_raises(UrlCanonicaliser::InvalidUrlError) do
      UrlCanonicaliser.canonicalize("ftp://example.com")
    end
  end

  test "raises error for javascript URL" do
    assert_raises(UrlCanonicaliser::InvalidUrlError) do
      UrlCanonicaliser.canonicalize("javascript:alert(1)")
    end
  end

  test "raises error for data URL" do
    assert_raises(UrlCanonicaliser::InvalidUrlError) do
      UrlCanonicaliser.canonicalize("data:text/html,<h1>Test</h1>")
    end
  end

  test "raises error for URL without host" do
    assert_raises(UrlCanonicaliser::InvalidUrlError) do
      UrlCanonicaliser.canonicalize("http:///path")
    end
  end

  # === Edge Cases ===

  test "handles URL with port" do
    result = UrlCanonicaliser.canonicalize("https://example.com:8080/page")
    assert_equal "https://example.com:8080/page", result
  end

  test "handles URL with fragment" do
    result = UrlCanonicaliser.canonicalize("https://example.com/page#section")
    assert_equal "https://example.com/page#section", result
  end

  test "handles URL with username and password" do
    result = UrlCanonicaliser.canonicalize("https://user:pass@example.com/page")
    assert_includes result, "user:pass@example.com"
  end

  test "handles URL with encoded characters" do
    result = UrlCanonicaliser.canonicalize("https://example.com/path%20with%20spaces")
    assert_includes result, "example.com"
  end

  test "handles international domain names" do
    result = UrlCanonicaliser.canonicalize("https://例え.jp/page")
    assert_equal "https://例え.jp/page", result
  end

  test "strips whitespace from URL" do
    result = UrlCanonicaliser.canonicalize("  https://example.com/page  ")
    assert_equal "https://example.com/page", result
  end

  test "handles HTTP URLs" do
    result = UrlCanonicaliser.canonicalize("http://example.com/page")
    assert_equal "http://example.com/page", result
  end
end
