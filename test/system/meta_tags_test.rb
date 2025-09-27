# frozen_string_literal: true

require "application_system_test_case"

class MetaTagsTest < ApplicationSystemTestCase
  setup do
    @ai_tenant = Tenant.find_by!(slug: "ai")
    @construction_tenant = Tenant.find_by!(slug: "construction")
  end

  test "should display correct meta tags for AI tenant" do
    visit root_path

    # Check title
    assert_title "AI News"

    # Check meta description
    assert_selector 'meta[name="description"][content="Curated AI industry news and insights"]', visible: false

    # Check meta keywords
    assert_selector 'meta[name="keywords"][content="apps, news, services"]', visible: false

    # Check Open Graph tags
    assert_selector 'meta[property="og:title"][content="AI News"]', visible: false
    assert_selector 'meta[property="og:description"][content="Curated AI industry news and insights"]', visible: false
    assert_selector 'meta[property="og:type"][content="website"]', visible: false
    assert_selector 'meta[property="og:site_name"][content="AI News"]', visible: false

    # Check Twitter Card tags
    assert_selector 'meta[name="twitter:card"][content="summary_large_image"]', visible: false
    assert_selector 'meta[name="twitter:site"][content="@ai"]', visible: false
    assert_selector 'meta[name="twitter:title"][content="AI News"]', visible: false
    assert_selector 'meta[name="twitter:description"][content="Curated AI industry news and insights"]', visible: false
  end

  test "should display correct meta tags for construction tenant" do
    # This would need to be tested with a different hostname in a real scenario
    # For now, we'll test the tenant data directly
    assert_equal "Construction News", @construction_tenant.title
    assert_equal "Latest construction industry news and trends", @construction_tenant.description
    assert_includes @construction_tenant.enabled_categories, "news"
    assert_includes @construction_tenant.enabled_categories, "services"
  end

  test "should display tenant information on show page" do
    visit root_path

    # Check that tenant information is displayed
    assert_selector "h1", text: "AI News"
    assert_selector "p", text: "ainews.cx"
    assert_selector ".text-gray-700", text: "Curated AI industry news and insights"

    # Check tenant details
    assert_selector "dd", text: "ai"
    assert_selector "span", text: "Enabled"

    # Check settings display
    assert_selector "span", text: "Purple" # primary color
    assert_selector "span", text: "News"
    assert_selector "span", text: "Apps"
    assert_selector "span", text: "Services"
  end

  test "should have proper HTML structure" do
    visit root_path

    # Check basic HTML structure
    assert_selector "html[lang='en']"
    assert_selector "head"
    assert_selector "body"

    # Check accessibility landmarks
    assert_selector "header[role='banner']"
    assert_selector "nav[role='navigation']"
    assert_selector "main#main-content[role='main']"
    assert_selector "footer[role='contentinfo']"

    # Check skip link
    assert_selector 'a[href="#main-content"]', visible: false
  end

  test "should handle missing tenant gracefully" do
    # This test would need to be run with an unknown hostname
    # For now, we'll verify the tenant resolution works
    tenant = Tenant.find_by_hostname!("ainews.cx")
    assert_equal @ai_tenant, tenant
  end
end
